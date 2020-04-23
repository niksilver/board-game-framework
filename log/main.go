// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Logging for the board game framework.
package log

import (
	"os"

	"github.com/inconshreveable/log15"
)

// Log is the logger, which discards everything by default
var Log = log15.New()

func init() {
	Log.SetHandler(log15.DiscardHandler())
}

func SetLvlDebugStdout() {
	Log.SetHandler(
		log15.LvlFilterHandler(
			log15.LvlDebug,
			log15.StreamHandler(os.Stdout, log15.LogfmtFormat()),
		))
}
