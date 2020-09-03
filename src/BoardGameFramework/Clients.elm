-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Clients exposing
  ( Client, Clients
  -- Build
  , empty, singleton, insert, update, remove
  -- Query
  , isEmpty, member, get
  )


{-| Functions for managing a list of clients (which may be players,
observers, or something else). This is actually just a
`Dict` from client ID keys to some value for a client, which is
a record including a field `id` holding the client ID.
There is also some help for JSON encoding and decoding.

The type `ClientId` comes from the base `BoardGameFramework` module.
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


{-| Update a specific client using a mapping function.

It's possible for for mapping function to produce `Just` value with
a different `id` from the one given. This would almost certainly be
an error. But if you did it, then the client with the `id` given will
be removed, and the value produced by the mapping function will be
inserted.
-}
update : BGF.ClientId -> (Maybe (Client e) -> Maybe (Client e)) -> Clients e -> Clients e
update id mapper cs =
  let
    maybeV2 = mapper (Dict.get id cs)
  in
  case maybeV2 of
    Nothing ->
      cs
      |> Dict.remove id

    Just v2 ->
      if v2.id == id then
        cs
        |> insert v2
      else
        cs
        |> Dict.remove id
        |> insert v2


{-| Remove a client from the client list.
-}
remove : BGF.ClientId -> Clients e -> Clients e
remove id cs =
  Dict.remove id cs


-- Query


{-| Is the client list empty?
-}
isEmpty : Clients e -> Bool
isEmpty cs =
  Dict.isEmpty cs


{-| See if a client with a given ID is in the client list.
-}
member : BGF.ClientId -> Clients e -> Bool
member id cs =
  Dict.member id cs


{-| Get a client by its ID.
-}
get : BGF.ClientId -> Clients e -> Maybe (Client e)
get id cs =
  Dict.get id cs
