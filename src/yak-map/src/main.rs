use std::collections::BTreeMap;
use std::path::PathBuf;
use zellij_tile::prelude::*;

pub mod model;
mod render;
pub mod repository;
mod tree;
mod util;

use model::ansi;
use model::TaskLine;
use repository::{InMemoryTaskSource, TaskRepository, TaskSource};

pub(crate) struct State {
    pub(crate) source: Box<dyn TaskSource>,
    pub(crate) repository: TaskRepository,
    pub(crate) tasks: Vec<TaskLine>,
    pub(crate) selected_index: usize,
    scroll_offset: usize,
    error: Option<String>,
    toast_message: Option<String>,
    toast_ticks_remaining: u8,
    pending_clipboard: Option<String>,
}

impl Default for State {
    fn default() -> Self {
        let repo = TaskRepository::default();
        Self {
            source: Box::new(InMemoryTaskSource::new()),
            repository: repo,
            tasks: Vec::new(),
            selected_index: 0,
            scroll_offset: 0,
            error: None,
            toast_message: None,
            toast_ticks_remaining: 0,
            pending_clipboard: None,
        }
    }
}

impl State {
    pub(crate) fn refresh_tasks(&mut self) {
        self.tasks = tree::build(self.source.as_ref());

        if self.tasks.is_empty() {
            self.selected_index = 0;
        } else if self.selected_index >= self.tasks.len() {
            self.selected_index = self.tasks.len() - 1;
        }
    }

    fn handle_show(&self) {
        let Some(task) = self.tasks.get(self.selected_index) else {
            return;
        };
        let script = format!(
            "COLUMNS=100 yx show {} | less -R; zellij action close-pane",
            task.yak_id
        );
        let command = CommandToRun {
            path: PathBuf::from("sh"),
            args: vec!["-c".to_string(), script],
            cwd: None,
        };
        let coords = FloatingPaneCoordinates::new(None, None, Some("102".to_string()), None, None);
        open_command_pane_floating(command, coords, BTreeMap::new());
    }

    fn handle_timer(&mut self) {
        set_timeout(2.0);
        self.refresh_tasks();
        if self.toast_ticks_remaining > 0 {
            self.toast_ticks_remaining -= 1;
            if self.toast_ticks_remaining == 0 {
                self.toast_message = None;
            }
        }
    }

    fn handle_navigate_up(&mut self) {
        if self.selected_index > 0 {
            self.selected_index -= 1;
        }
    }

    fn handle_navigate_down(&mut self) {
        if self.selected_index + 1 < self.tasks.len() {
            self.selected_index += 1;
        }
    }

    fn handle_edit_context(&self) {
        let Some(task) = self.tasks.get(self.selected_index) else {
            return;
        };
        let context_path = self.repository.context_path(&task.path);
        if let Some(parent) = context_path.parent() {
            let _ = std::fs::create_dir_all(parent);
        }
        if !context_path.exists() {
            let _ = std::fs::write(&context_path, "");
        }
        let host_path = context_path
            .strip_prefix("/host")
            .unwrap_or(&context_path)
            .to_path_buf();
        let file_to_open = FileToOpen::new(host_path);
        open_file_floating(file_to_open, None, BTreeMap::new());
    }

    fn handle_yank(&mut self) {
        let Some(task) = self.tasks.get(self.selected_index) else {
            return;
        };
        util::copy_via_zellij_tty(&task.yak_id);
        self.pending_clipboard = Some(task.yak_id.clone());
        self.toast_message = Some(format!("Copied: {}", task.yak_id));
        self.toast_ticks_remaining = 1;
    }

    fn handle_refresh(&mut self) {
        self.refresh_tasks();
    }

    fn handle_key(&mut self, key: KeyWithModifier) -> bool {
        if !key.has_no_modifiers() {
            return false;
        }
        match key.bare_key {
            BareKey::Up | BareKey::Char('k') => {
                self.handle_navigate_up();
                true
            }
            BareKey::Down | BareKey::Char('j') => {
                self.handle_navigate_down();
                true
            }
            BareKey::Char('r') => {
                self.handle_refresh();
                true
            }
            BareKey::Char('e') => {
                self.handle_edit_context();
                true
            }
            BareKey::Char('y') => {
                self.handle_yank();
                true
            }
            BareKey::Enter => {
                self.handle_show();
                true
            }
            _ => false,
        }
    }
}

impl ZellijPlugin for State {
    fn load(&mut self, _configuration: BTreeMap<String, String>) {
        subscribe(&[EventType::Timer, EventType::Key]);
        set_timeout(2.0);
        request_permission(&[PermissionType::OpenFiles, PermissionType::RunCommands]);

        let yaks_dir = PathBuf::from("/host/.yaks");

        if !yaks_dir.exists() {
            self.error = Some(format!(
                "Yaks directory not found: {}\nRun `yx add <name>` to create a task.",
                yaks_dir.display()
            ));
            return;
        }

        let repo = TaskRepository::new(yaks_dir);
        self.source = Box::new(TaskRepository::new(repo.yaks_dir().clone()));
        self.repository = repo;
        self.refresh_tasks();
    }

    fn update(&mut self, event: Event) -> bool {
        match event {
            Event::Timer(_) => {
                self.handle_timer();
                true
            }
            Event::Key(key) => self.handle_key(key),
            _ => false,
        }
    }

    fn render(&mut self, rows: usize, cols: usize) {
        let _ = self.pending_clipboard.take();

        if let Some(error) = &self.error {
            println!("{}Error: {}{}", ansi::RED, error, ansi::RESET);
            return;
        }

        if self.tasks.is_empty() {
            println!("No tasks. Run `yx add <name>` to create one.");
            println!("(Refresh interval: 2s)");
            return;
        }

        let toast_rows = if self.toast_message.is_some() { 2 } else { 0 };
        let max_rows = rows.saturating_sub(3 + toast_rows);

        if self.selected_index < self.scroll_offset {
            self.scroll_offset = self.selected_index;
        } else if max_rows > 0 && self.selected_index >= self.scroll_offset + max_rows {
            self.scroll_offset = self.selected_index - max_rows + 1;
        }

        for (i, task) in self
            .tasks
            .iter()
            .skip(self.scroll_offset)
            .take(max_rows)
            .enumerate()
        {
            let line = render::render_task(task);

            if self.scroll_offset + i == self.selected_index {
                let visible_len = util::line_display_width(&line);
                let padding = " ".repeat(cols.saturating_sub(visible_len));
                println!("{}", render::highlight_line(&line, &padding));
            } else {
                println!("{}", line);
            }
        }

        if let Some(msg) = &self.toast_message.clone() {
            println!();
            let toast = format!(" {} ", msg);
            println!("{}{}{}{}", ansi::REVERSE, ansi::BOLD, toast, ansi::RESET);
        }
    }
}

register_plugin!(State);

#[cfg(test)]
mod contrast_tests {
    // Verify LIGHT palette colors meet WCAG AA (4.5:1) against Ghostty biscotty bg #f5ede5.
    // 256-color cube: index 16-231, channel values [0,95,135,175,215,255] for indices 0-5.
    // Grayscale ramp 232-255: value = 8 + (index - 232) * 10.

    const BG_BISCOTTY: (u8, u8, u8) = (245, 237, 229); // #f5ede5

    fn linear(c: u8) -> f32 {
        let v = c as f32 / 255.0;
        if v <= 0.04045 {
            v / 12.92
        } else {
            ((v + 0.055) / 1.055).powf(2.4)
        }
    }

    fn luminance(rgb: (u8, u8, u8)) -> f32 {
        0.2126 * linear(rgb.0) + 0.7152 * linear(rgb.1) + 0.0722 * linear(rgb.2)
    }

    fn contrast(fg: (u8, u8, u8), bg: (u8, u8, u8)) -> f32 {
        let l1 = luminance(fg);
        let l2 = luminance(bg);
        let (lighter, darker) = if l1 > l2 { (l1, l2) } else { (l2, l1) };
        (lighter + 0.05) / (darker + 0.05)
    }

    #[test]
    fn light_red_contrast_ratio() {
        // LIGHT.red = "\x1b[38;5;124m" = 256-color 124 = rgb(175, 0, 0)
        let ratio = contrast((175, 0, 0), BG_BISCOTTY);
        assert!(ratio >= 4.5, "LIGHT red {:.2}:1 < 4.5:1", ratio);
    }

    #[test]
    fn light_green_contrast_ratio() {
        // LIGHT.green = "\x1b[38;5;22m" = 256-color 22 = rgb(0, 95, 0)
        let ratio = contrast((0, 95, 0), BG_BISCOTTY);
        assert!(ratio >= 4.5, "LIGHT green {:.2}:1 < 4.5:1", ratio);
    }

    #[test]
    fn light_yellow_contrast_ratio() {
        // LIGHT.yellow = "\x1b[38;5;94m" = 256-color 94 = rgb(135, 95, 0)
        let ratio = contrast((135, 95, 0), BG_BISCOTTY);
        assert!(ratio >= 4.5, "LIGHT yellow {:.2}:1 < 4.5:1", ratio);
    }

    #[test]
    fn light_cyan_contrast_ratio() {
        // LIGHT.cyan = "\x1b[38;5;23m" = 256-color 23 = rgb(0, 95, 95)
        let ratio = contrast((0, 95, 95), BG_BISCOTTY);
        assert!(ratio >= 4.5, "LIGHT cyan {:.2}:1 < 4.5:1", ratio);
    }

    #[test]
    fn light_dim_contrast_ratio() {
        // LIGHT.dim = "\x1b[38;5;240m" = 256-color 240 (grayscale) = rgb(88, 88, 88)
        let ratio = contrast((88, 88, 88), BG_BISCOTTY);
        assert!(ratio >= 4.5, "LIGHT dim {:.2}:1 < 4.5:1", ratio);
    }

    #[test]
    fn biscotty_bg_luminance_triggers_light_mode() {
        // The biscotty Zellij theme sets text_unselected.background = 245 237 229 (#f5ede5).
        // ModeUpdate checks this luminance against 0.5. Verify it exceeds the threshold.
        let lum = luminance(BG_BISCOTTY);
        assert!(
            lum > 0.5,
            "biscotty bg luminance {:.3} should be > 0.5 to trigger light mode",
            lum
        );
    }

    #[test]
    fn gruvbox_bg_luminance_keeps_dark_mode() {
        // gruvbox text_unselected.background = 60 56 54 — must stay below 0.5 (dark mode).
        let gruvbox_bg = (60u8, 56u8, 54u8);
        let lum = luminance(gruvbox_bg);
        assert!(
            lum < 0.5,
            "gruvbox bg luminance {:.3} should be < 0.5 to keep dark mode",
            lum
        );
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn refresh_tasks_handles_empty_source() {
        let mut state = State {
            selected_index: 5,
            ..Default::default()
        };
        state.refresh_tasks();

        assert!(state.tasks.is_empty());
        assert_eq!(state.selected_index, 0);
    }

    #[test]
    fn refresh_tasks_selected_index_bounded() {
        let mut src = InMemoryTaskSource::new();
        src.add_task("task-a", 0);

        let mut state = State {
            source: Box::new(src),
            selected_index: 10,
            ..Default::default()
        };
        state.refresh_tasks();

        assert_eq!(state.selected_index, 0);
    }
}
