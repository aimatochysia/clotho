//! Who commits are made as. The app keeps a list of identities; when none is
//! chosen, Git's own `user.name` / `user.email` config is used.

use git2::{Repository, Signature};
use serde::{Deserialize, Serialize};

use crate::error::{CoreError, CoreResult};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Identity {
    pub name: String,
    pub email: String,
}

/// The identity Git would use: the repository's config when `path` is given,
/// otherwise the global config. None when name or email is missing.
pub fn git_identity(path: Option<String>) -> Option<Identity> {
    let config = match path {
        Some(p) => Repository::open(p).ok()?.config().ok()?,
        None => git2::Config::open_default().ok()?,
    };
    let name = config.get_string("user.name").ok()?;
    let email = config.get_string("user.email").ok()?;
    let id = Identity {
        name: name.trim().to_string(),
        email: email.trim().to_string(),
    };
    (!id.name.is_empty() && !id.email.is_empty()).then_some(id)
}

/// Checks and tidies an identity the person typed.
pub fn validate_identity(identity: Identity) -> CoreResult<Identity> {
    let name = identity.name.trim().to_string();
    let email = identity.email.trim().to_string();
    if name.is_empty() {
        return Err(CoreError::InvalidInput {
            message: "enter a name".into(),
        });
    }
    let at = email.find('@');
    let ok = matches!(at, Some(i) if i > 0 && i < email.len() - 1)
        && !email.contains(char::is_whitespace)
        && !email.contains(['<', '>']);
    if !ok {
        return Err(CoreError::InvalidInput {
            message: format!("\"{email}\" is not an email address"),
        });
    }
    if name.contains(['<', '>', '\n']) {
        return Err(CoreError::InvalidInput {
            message: "the name cannot contain < > or line breaks".into(),
        });
    }
    Ok(Identity { name, email })
}

/// The signature for a new commit: `identity` when given, else Git config.
pub(crate) fn signature(
    repo: &Repository,
    identity: Option<&Identity>,
) -> CoreResult<Signature<'static>> {
    match identity {
        Some(id) => {
            let id = validate_identity(id.clone())?;
            Ok(Signature::now(&id.name, &id.email)?)
        }
        None => repo.signature().map_err(|_| CoreError::MissingIdentity),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::util::testutil::TestRepo;

    fn id(name: &str, email: &str) -> Identity {
        Identity {
            name: name.into(),
            email: email.into(),
        }
    }

    #[test]
    fn validation() {
        assert_eq!(
            validate_identity(id("  Hael ", " h@example.com ")).unwrap(),
            id("Hael", "h@example.com")
        );
        assert!(validate_identity(id("", "h@example.com")).is_err());
        assert!(validate_identity(id("H", "nope")).is_err());
        assert!(validate_identity(id("H", "@x")).is_err());
        assert!(validate_identity(id("H", "a b@x.y")).is_err());
        assert!(validate_identity(id("<H>", "h@x.y")).is_err());
    }

    #[test]
    fn explicit_identity_wins_over_config() {
        let t = TestRepo::new("main");
        let sig = signature(&t.repo, Some(&id("Other", "o@example.com"))).unwrap();
        assert_eq!(sig.name(), Some("Other"));
        let sig = signature(&t.repo, None).unwrap();
        assert_eq!(sig.name(), Some("Test User"));
        assert_eq!(git_identity(Some(t.path())).unwrap().name, "Test User");
    }
}
