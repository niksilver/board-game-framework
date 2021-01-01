# Paper, scissors, rock

This game demonstrates two things:
* Each player having a hidden state - their hand is revealed only when both
  players have made their choice.
* Players have roles, which can change. The game is for exactly two players;
  others are observers until one player leaves, at which point an observer
  can opt to play.

## Files and compilation

* *src/Main.elm*. The main Elm app.
* *psr.html*. The shell page that the Elm app drops
  into. It sets up the JavaScript side of the ports integration and
  the initialisation values.
* *lib/board-game-framework.js*. A copy of the JavaScript framework library
  used by the shell page.

## Compiling and running

Compile the Elm app using

```
elm make src/Main.elm --output=psr.js
```

and then use `elm reactor` to view `psr.html` to see it running.
You need reactor because it's a `Browser.application`,
which relies on running from a server, not the local filesystem.

## Credits

* Paper image by [Alexander Skowalsky, HU ](https://thenounproject.com/search/?q=paper&i=979371)
* Scissors image by [Abid Muhammad, ID](https://www.pngitem.com/middle/hJmhwTi_sheet-of-paper-icon-paper-sheet-icon-hd/)
* Rock image by [Lemon Liu, NZ](https://thenounproject.com/term/stone/117090/)
