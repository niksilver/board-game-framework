-- Copyright 2020 Nik Silver
--
-- Licensed under the GPL v3.0. See file LICENCE.txt for details.


module BoardGameFramework.Clients exposing
  -- Basic types
  ( Client, Clients
  -- Build
  , empty, singleton, insert, update, remove
  -- Query
  , isEmpty, member, get, size, filterSize
  -- Lists and dicts
  , ids, toList, toDict, fromList
  -- Transform
  , map, fold, filter, partition
  -- Combine
  , union, intersect, diff
  -- JSON
  , encode, decoder
  )


{-| Functions for managing a list of clients (which may be players,
observers, or something else).

Each client is simply a record with an `id` field of type `ClientId`,
and other fields as desired.
The client list will never contain more than one
element with the same `ClientId`.
The API is based heavily on that of `Dict`.

The type `ClientId` comes from the base `BoardGameFramework` module.

# Basic types
@docs Client, Clients

#Build
@docs empty, singleton, insert, update, remove

#Query
@docs isEmpty, member, get, size, filterSize

#Lists and dicts
@docs ids, toList, toDict, fromList

#Transform
@docs map, fold, filter, partition

#Combine
@docs union, intersect, diff

# JSON
@docs encode, decoder
-}


import Dict exposing (Dict)
import Json.Encode as Enc
import Json.Decode as Dec

import BoardGameFramework as BGF


-- Basic types


{-| A player, observer, or similar.
-}
type alias Client e =
  { e
  | id : BGF.ClientId
  }


{-| A list of clients.
-}
type Clients e =
  Clients (Dict BGF.ClientId (Client e))


{-| An empty client list.
-}
empty : Clients e
empty =
  Dict.empty
  |> Clients


{-| A client list with one client.
-}
singleton : Client e -> Clients e
singleton c =
  Dict.singleton c.id c
  |> Clients


{-| Insert a client, or replace an existing one.
-}
insert : Client e -> Clients e -> Clients e
insert c (Clients cs) =
  cs
  |> Dict.insert c.id c
  |> Clients


{-| Update a specific client using a mapping function.

It's possible for for mapping function to produce `Just` value with
a different `id` from the one given. This would almost certainly be
an error. But if you did it, then the client with the `id` given will
be removed, and the value produced by the mapping function will be
inserted.
-}
update : BGF.ClientId -> (Maybe (Client e) -> Maybe (Client e)) -> Clients e -> Clients e
update id mapper (Clients cs) =
  let
    maybeV2 = mapper (Dict.get id cs)
  in
  case maybeV2 of
    Nothing ->
      cs
      |> Dict.remove id
      |> Clients

    Just v2 ->
      if v2.id == id then
        cs
        |> Clients
        |> insert v2
      else
        cs
        |> Dict.remove id
        |> Clients
        |> insert v2


{-| Remove a client from the client list.
-}
remove : BGF.ClientId -> Clients e -> Clients e
remove id (Clients cs) =
  Dict.remove id cs
  |> Clients


-- Query


{-| Is the client list empty?
-}
isEmpty : Clients e -> Bool
isEmpty (Clients cs) =
  Dict.isEmpty cs


{-| See if a client with a given ID is in the client list.
-}
member : BGF.ClientId -> Clients e -> Bool
member id (Clients cs) =
  Dict.member id cs


{-| Get a client by its ID.
-}
get : BGF.ClientId -> Clients e -> Maybe (Client e)
get id (Clients cs) =
  Dict.get id cs


{-| The number of clients in the list.
-}
size : Clients e -> Int
size (Clients cs) =
  Dict.size cs


{-| The number of clients that pass a test.

Here's how we might count all those in `TeamA`:

    clients
    |> filterSize (\c -> c.team == TeamA)
-}
filterSize : (Client e -> Bool) -> Clients e -> Int
filterSize fn cs =
  filter fn cs
  |> size


-- Lists and dicts

{-| Get a list of all the client IDs.
-}
ids : Clients e -> List BGF.ClientId
ids (Clients cs) =
  Dict.keys cs


{-| Get all the clients as a list.
-}
toList : Clients e -> List (Client e)
toList (Clients cs) =
  Dict.values cs


{-| Get all the clients a `Dict` mapping from client ID.
-}
toDict : Clients e -> Dict BGF.ClientId (Client e)
toDict (Clients cs) =
  cs


{-| Turn a `List` of clients into a `Clients e`.
If the `List` has more than one element with the same `id` then only
one of those will end up in the output, and which one is not predictable.
-}
fromList : List (Client e) -> Clients e
fromList cls =
  cls
  |> List.map (\c -> (c.id, c))
  |> Dict.fromList
  |> Clients


-- Transform


{-| Apply a function to all clients.

The function could change an `id`. That almost certainly be a bad idea, but
if it happened then the resulting client list would still have one
element per `id`.

Here's how we might reset everyone's score to zero:

    clients
    |> map (\c -> { c | score = 0})
-}
map : (Client e -> Client f) -> Clients e -> Clients f
map fn (Clients cs) =
  let
    insrt k v dict =
      let
        v2 = fn v
      in
      Dict.insert v2.id v2 dict
  in
  cs
  |> Dict.foldl insrt Dict.empty
  |> Clients


{-| Fold over all the clients. Order of processing is not guaranteed.

Here's how to add up everyone's score:

    clients
    |> fold (\c n -> c.score + n) 0
-}
fold : (Client e -> f -> f) -> f -> Clients e -> f
fold fn z (Clients cs) =
  let
    fn2 _ v n =
      fn v n
  in
  Dict.foldl fn2 z cs


{-| Keep only those clients that pass a test.

Here's how we might get all those in `TeamA`:

    clients
    |> filter (\c -> c.team == TeamA)
-}
filter : (Client e -> Bool) -> Clients e -> Clients e
filter fn (Clients cs) =
  let
    fn2 _ v =
      fn v
  in
  cs
  |> Dict.filter fn2
  |> Clients


{-| Split the client list into two: those who pass a test (first
element of the pair), and those who don't.

If `player` is a Boolean field distinguishing a participant from an
observer, then here's how we might split the two:

    partition .player clients
-}
partition : (Client e -> Bool) -> Clients e -> (Clients e, Clients e)
partition fn (Clients cs) =
  let
    fn2 _ v =
      fn v
  in
  cs
  |> Dict.partition fn2
  |> Tuple.mapBoth Clients Clients


-- Combine


{-| Combine two client lists. If a client with the same `id` appears
in both lists, then the one from the first list will survive.
-}
union : Clients e -> Clients e -> Clients e
union (Clients cs1) (Clients cs2) =
  Dict.union cs1 cs2
  |> Clients


{-| Find clients with `id`s that are in both client lists.
The client from the first list will be preserved.
-}
intersect : Clients e -> Clients e -> Clients e
intersect (Clients cs1) (Clients cs2) =
  Dict.intersect cs1 cs2
  |> Clients



{-| Find clients from the first list whose 'id` isn't in the second list.
-}
diff : Clients e -> Clients e -> Clients e
diff (Clients cs1) (Clients cs2) =
  Dict.diff cs1 cs2
  |> Clients


-- JSON


{-| Encode a client list. You need to provide encoders for each field
(but not the `id` field - that's taken care of).

If we have a client list `cs` with a `name` field and a Boolean
`player` field, then this is how we might encode it:

    encodeClients : Clients e -> Value
    encodeClients =
      encode
      [ ("name", .name >> Enc.string)
      , ("player", .player >> Enc.bool)
      ]

    encodedClients : Value
    encodedClients =
      encodeClients cs
-}
encode : List (String, Client e -> Enc.Value) -> Clients e -> Enc.Value
encode trans (Clients cs) =
  let
    -- Put the id translation into the list
    transFull =
      ("id", .id >> Enc.string) :: trans

    clientPairs : Client e -> List (String, Enc.Value)
    clientPairs c =
      List.map (\(name, fn) -> (name, fn c)) transFull

    encodeOneClient : Client e -> Enc.Value
    encodeOneClient c =
      Enc.object (clientPairs c)
  in
  Enc.dict identity encodeOneClient cs


{-| A decoder for a client list. You need to provide a decoder for
a `Client`.
Recall that the `id` field is a `ClientId`, which is just an alias for
`String`.
-}
decoder : Dec.Decoder (Client e) -> Dec.Decoder (Clients e)
decoder fn =
  Dec.dict fn
  |> Dec.map Clients
