package main

import (
	"log"

	"github.com/yakthang/yakbox/cmd"
)

func main() {
	if err := cmd.Execute(); err != nil {
		log.Fatal(err)
	}
}
