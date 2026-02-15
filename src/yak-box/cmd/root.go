package cmd

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "yak-box",
	Short: "Docker-based worker orchestration CLI",
	Long:  "yak-box is a CLI tool for managing sandboxed and native workers",
}

func Execute() error {
	return rootCmd.Execute()
}

func init() {
	rootCmd.AddCommand(spawnCmd)
	rootCmd.AddCommand(stopCmd)
	rootCmd.AddCommand(checkCmd)
}
