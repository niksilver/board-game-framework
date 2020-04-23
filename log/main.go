// Copyright 2020 Nik Silver
//
// Licensed under the GPL v3.0. See file LICENCE.txt for details.

// Logging for the board game framework.
package log

import (
	"os"

	"github.com/inconshreveable/log15"
)

var Log = log15.New()

func init() {
	handler := log15.LvlFilterHandler(
		log15.LvlCrit,
		log15.StreamHandler(os.Stdout, log15.LogfmtFormat()),
	)
	Log.SetHandler(handler)
}
