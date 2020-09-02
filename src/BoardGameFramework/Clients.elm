-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Clients exposing
  ( Client, Clients
  -- Build
  , empty, singleton, insert
  )


{-| Functions for managing a list of clients (which may be players,
observers, or something else). This is actually just a
`Dict` from client ID keys to some value for a client, which is
a record including a field `id` holding the client ID.
There is also some help for JSON encoding and decoding.
-}


import Dict exposing (Dict)

import BoardGameFramework as BGF


{-| A player, observer, or similar.
-}
type alias Client e =
  { e
  | id : BGF.ClientId
  }


{-| A list of clients.
-}
type alias Clients e =
  Dict BGF.ClientId (Client e)


{-| An empty client list.
-}
empty : Clients e
empty =
  Dict.empty


{-| A client list with one client.
-}
singleton : Client e -> Clients e
singleton c =
  Dict.singleton c.id c


{-| Insert a client, or replace an existing one.
-}
insert : Client e -> Clients e -> Clients e
insert c cs =
  cs
  |> Dict.insert c.id c
