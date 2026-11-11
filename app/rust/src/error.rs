use thiserror::Error;

/// Every failure the core can report to the UI. The Dart side receives this as a
/// typed exception, so it can show a specific message for each case.
#[derive(Debug, Error)]
pub enum CoreError {
    #[error("not a Git repository: {path}")]
    NotARepository { path: String },
    #[error("path does not exist: {path}")]
    PathNotFound { path: String },
    #[error("nothing to commit")]
    NothingToCommit,
    #[error("set user.name and user.email in your Git config before committing")]
    MissingIdentity,
    #[error("resolve conflicts first: {files:?}")]
    Conflicts { files: Vec<String> },
    #[error("cannot fast-forward; the branches have diverged")]
    NotFastForward,
    #[error("local changes would be overwritten: {message}")]
    DirtyWorktree { message: String },
    #[error("branch {name} has commits that are not merged")]
    BranchNotMerged { name: String },
    #[error("branch {branch} has no upstream")]
    NoUpstream { branch: String },
    #[error("HEAD is detached; check out a branch first")]
    DetachedHead,
    #[error("authentication failed: {message}")]
    Auth { message: String },
    #[error("push rejected: {message}")]
    PushRejected { message: String },
    #[error("{message}")]
    InvalidInput { message: String },
    #[error("file error: {message}")]
    Io { message: String },
    #[error("git error: {message}")]
    Git { message: String },
}

impl From<git2::Error> for CoreError {
    fn from(err: git2::Error) -> Self {
        let message = err.message().to_string();
        match err.code() {
            git2::ErrorCode::Auth => CoreError::Auth { message },
            git2::ErrorCode::Conflict | git2::ErrorCode::Uncommitted => {
                CoreError::DirtyWorktree { message }
            }
            git2::ErrorCode::NotFastForward => CoreError::NotFastForward,
            _ if matches!(err.class(), git2::ErrorClass::Ssh)
                && message.to_lowercase().contains("auth") =>
            {
                CoreError::Auth { message }
            }
            _ => CoreError::Git { message },
        }
    }
}

impl From<std::io::Error> for CoreError {
    fn from(err: std::io::Error) -> Self {
        CoreError::Io {
            message: err.to_string(),
        }
    }
}

impl From<serde_json::Error> for CoreError {
    fn from(err: serde_json::Error) -> Self {
        CoreError::Io {
            message: format!("settings file is invalid: {err}"),
        }
    }
}

pub type CoreResult<T> = Result<T, CoreError>;
