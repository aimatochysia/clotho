use thiserror::Error;

/// Every failure the core can report to the UI. The Dart side receives this as a
/// typed exception, so it can tell "not a repository" apart from a Git or IO failure.
#[derive(Debug, Error)]
pub enum CoreError {
    #[error("not a Git repository: {path}")]
    NotARepository { path: String },
    #[error("path does not exist: {path}")]
    PathNotFound { path: String },
    #[error("git error: {message}")]
    Git { message: String },
}

impl From<git2::Error> for CoreError {
    fn from(err: git2::Error) -> Self {
        CoreError::Git {
            message: err.message().to_string(),
        }
    }
}
