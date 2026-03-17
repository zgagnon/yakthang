pub mod ansi {
    pub const RED: &str = "\x1b[31m";
    pub const GREEN: &str = "\x1b[32m";
    pub const YELLOW: &str = "\x1b[33m";
    pub const CYAN: &str = "\x1b[36m";
    pub const WHITE: &str = "\x1b[37m";
    pub const DIM: &str = "\x1b[90m";
    pub const RESET: &str = "\x1b[0m";
    pub const BOLD: &str = "\x1b[1m";
    pub const REVERSE: &str = "\x1b[7m";
    pub const STRIKETHROUGH: &str = "\x1b[9m";
    pub const BG_SELECTED: &str = "\x1b[48;5;237m";
}

pub struct ColorScheme {
    pub red: &'static str,
    pub green: &'static str,
    pub yellow: &'static str,
    pub cyan: &'static str,
    pub fg_normal: &'static str,
    pub dim: &'static str,
    pub reset: &'static str,
    pub bold: &'static str,
    pub reverse: &'static str,
    pub strikethrough: &'static str,
    pub bg_selected: &'static str,
}

pub const DARK: ColorScheme = ColorScheme {
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
    fg_normal: "\x1b[37m",
    dim: "\x1b[90m",
    reset: "\x1b[0m",
    bold: "\x1b[1m",
    reverse: "\x1b[7m",
    strikethrough: "\x1b[9m",
    bg_selected: "\x1b[48;5;237m",
};

pub const LIGHT: ColorScheme = ColorScheme {
    red: "\x1b[31m",
    green: "\x1b[32m",
    yellow: "\x1b[33m",
    cyan: "\x1b[36m",
    fg_normal: "\x1b[39m",
    dim: "\x1b[90m",
    reset: "\x1b[0m",
    bold: "\x1b[1m",
    reverse: "\x1b[7m",
    strikethrough: "\x1b[9m",
    bg_selected: "\x1b[48;5;252m",
};

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TaskState {
    Wip,
    Todo,
    Done,
}

impl std::str::FromStr for TaskState {
    type Err = String;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        match s {
            "wip" => Ok(TaskState::Wip),
            "done" => Ok(TaskState::Done),
            "todo" => Ok(TaskState::Todo),
            _ => Err(format!(
                "Invalid task state '{}'. Valid states are: todo, wip, done",
                s
            )),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum AgentStatusKind {
    Blocked,
    Done,
    Wip,
    Unknown,
}

impl AgentStatusKind {
    pub fn from_status_string(s: &str) -> Self {
        if s.starts_with("blocked:") {
            AgentStatusKind::Blocked
        } else if s.starts_with("done:") {
            AgentStatusKind::Done
        } else if s.starts_with("wip:") {
            AgentStatusKind::Wip
        } else {
            AgentStatusKind::Unknown
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ReviewStatusKind {
    Pass,
    Fail,
    InProgress,
    Unknown,
}

impl ReviewStatusKind {
    pub fn from_status_string(s: &str) -> Self {
        let v = s.trim().to_lowercase();
        if v.starts_with("in-progress") || v.starts_with("in_progress") {
            ReviewStatusKind::InProgress
        } else if v.starts_with("pass") {
            ReviewStatusKind::Pass
        } else if v.starts_with("fail") {
            ReviewStatusKind::Fail
        } else {
            ReviewStatusKind::Unknown
        }
    }
}

#[derive(Debug, Clone)]
pub struct TaskLine {
    pub path: String,
    pub name: String,
    pub yak_id: String,
    pub depth: usize,
    pub state: TaskState,
    pub assigned_to: Option<String>,
    pub agent_status: Option<String>,
    pub review_status: Option<String>,
    pub has_children: bool,
    pub is_last_sibling: bool,
    pub ancestor_continuations: Vec<bool>,
}

impl Default for TaskLine {
    fn default() -> Self {
        Self {
            path: String::new(),
            name: String::new(),
            yak_id: String::new(),
            depth: 0,
            state: TaskState::Todo,
            assigned_to: None,
            agent_status: None,
            review_status: None,
            has_children: false,
            is_last_sibling: false,
            ancestor_continuations: Vec::new(),
        }
    }
}
