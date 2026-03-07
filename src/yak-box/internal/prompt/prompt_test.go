package prompt

import (
	"strings"
	"testing"
)

func TestBuildPrompt_PlanMode(t *testing.T) {
	out := BuildPrompt("plan", "/.yaks", "User says: do X", nil, "", nil)
	if !strings.Contains(out, "Do NOT pick up the clippers") {
		t.Error("plan mode should tell worker not to implement")
	}
	if !strings.Contains(out, "Your job is to plan, not build") {
		t.Error("plan mode should emphasize planning only")
	}
	if !strings.Contains(out, "User says: do X") {
		t.Error("user prompt should be included")
	}
	if !strings.Contains(out, "/.yaks") {
		t.Error("yakPath should appear in prompt")
	}
}

func TestBuildPrompt_DefaultMode(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Fix the bug", nil, "", nil)
	if !strings.Contains(out, "shave them clean") {
		t.Error("default mode should say shave them clean")
	}
	if !strings.Contains(out, "Fix the bug") {
		t.Error("user prompt should be included")
	}
}

func TestBuildPrompt_WithShaverName(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", nil, "Yakoff", nil)
	if !strings.Contains(out, "You are Yakoff") {
		t.Errorf("shaver name should appear: %q", out)
	}
}

func TestBuildPrompt_SingleTask(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", []string{"fix-auth"}, "", nil)
	if !strings.Contains(out, "ASSIGNED TASK") {
		t.Error("single task should have ASSIGNED TASK section")
	}
	if !strings.Contains(out, "fix-auth") {
		t.Error("task name should appear")
	}
	if !strings.Contains(out, "yx context --show fix-auth") {
		t.Error("should mention context for the task")
	}
}

func TestBuildPrompt_MultipleTasks(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", []string{"task-a", "task-b"}, "", nil)
	if !strings.Contains(out, "ASSIGNED TASKS") {
		t.Error("multiple tasks should have ASSIGNED TASKS section")
	}
	if !strings.Contains(out, "task-a") || !strings.Contains(out, "task-b") {
		t.Error("all task names should appear")
	}
}

func TestBuildPrompt_NoTasks(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", nil, "", nil)
	if !strings.Contains(out, "TASK TRACKER (yx)") {
		t.Error("should include task tracker section")
	}
	if strings.Contains(out, "ASSIGNED TASK") {
		t.Error("no ASSIGNED TASK when tasks empty")
	}
}

func TestBuildPrompt_WithSkills(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", nil, "", []string{"skill-a", "skill-b"})
	if !strings.Contains(out, "SKILLS") {
		t.Error("skills section should be present")
	}
	if !strings.Contains(out, "skill-a") || !strings.Contains(out, "skill-b") {
		t.Error("skill names should be listed")
	}
	if !strings.Contains(out, "BEFORE DOING ANYTHING ELSE") {
		t.Error("should instruct to invoke skills first")
	}
}

func TestBuildPrompt_NoSkills(t *testing.T) {
	out := BuildPrompt("", "/.yaks", "Hi", nil, "", nil)
	if strings.Contains(out, "SKILLS") {
		t.Error("no SKILLS section when skillNames empty")
	}
}
