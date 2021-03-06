(*
 * Copyright (C) 2011-2012 Mauricio Fernandez <mfp@acm.org>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version,
 * with the special exception on linking described in file LICENSE.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 *)

open Lwt

module DM = Obs_data_model
module Option = BatOption
module List = struct include List include BatList end
open DM

type ('key, 'row) row_func =
   [ `Raw of ('key, string) key_data -> 'row option
   | `BSON of ('key, decoded_data) key_data -> 'row option ]

module type TABLE_CONFIG =
sig
  type 'key row

  module Codec : Obs_key_encoding.CODEC_OPS
  val name : string

  val row_of_key_data : (Codec.key, Codec.key row) row_func
  val row_needs_timestamps : bool
end

module Trivial_row =
struct
  type 'key row = ('key, string) key_data
  let row_of_key_data = `Raw (fun d -> Some d)
  let row_needs_timestamps = true
end

let key_range_with_prefix c ?starting_with p =
  let open Obs_key_encoding in
  let first = match starting_with with
      None -> Some (expand (p (fun x -> part x @@ min_suffix)) c);
    | Some _ as key -> key
  in
    `Continuous
      { first; reverse = false;
        up_to = Some (succ_value c (expand (p (fun x -> part x @@ max_suffix)) c));
      }

let range_with_prefix = key_range_with_prefix

let encode_range c r =
  let open Obs_key_encoding in
  let `Continuous r = r in
    `Continuous
      { r with first = Option.map (encode_to_string c) r.first;
               up_to = Option.map (encode_to_string c) r.up_to; }


let encoded_range_with_prefix c ?starting_with p =
  encode_range c (key_range_with_prefix c ?starting_with p)

let rev_key_range_with_prefix c ?starting_with p =
  let open Obs_key_encoding in
  let first = match starting_with with
      None -> Some (succ_value c (expand (p (fun x -> part x @@ max_suffix)) c));
    | Some key -> Some (succ_value c key)
  in
    `Continuous
      { first; reverse = true;
        up_to = Some (expand (p (fun x -> part x @@ min_suffix)) c);
      }

let rev_range_with_prefix = rev_key_range_with_prefix

let encoded_rev_range_with_prefix c ?starting_with p =
  encode_range c (rev_key_range_with_prefix c ?starting_with p)

module Make
  (M : TABLE_CONFIG)
  (OP : Obs_data_model.S) =
struct
  open OP
  module C = M.Codec
  module Codec = M.Codec

  type keyspace = OP.keyspace
  type key = M.Codec.key
  type key_range = [`Continuous of key range | `Discrete of key list | `All]

  let key_range_with_prefix ?starting_with p =
    key_range_with_prefix C.codec ?starting_with p

  let rev_key_range_with_prefix ?starting_with p =
    rev_key_range_with_prefix C.codec ?starting_with p

  let table = table_of_string M.name

  let size_on_disk ks = table_size_on_disk ks table

  let key_range_size_on_disk ks ?first ?up_to () =
    key_range_size_on_disk ks
      ?first:(Option.map C.encode_to_string first)
      ?up_to:(Option.map C.encode_to_string up_to)
      table

  let read_committed_transaction = OP.read_committed_transaction
  let repeatable_read_transaction = OP.repeatable_read_transaction
  let lock = OP.lock

  let inject_range = function
      `Discrete l -> `Discrete (List.map C.encode_to_string l)
    | `All -> `All
    | `Continuous kr ->
      `Continuous
        { kr with first = Option.map C.encode_to_string kr.first;
                  up_to = Option.map C.encode_to_string kr.up_to; }

  let get_keys ks ?max_keys range =
    get_keys ks table ?max_keys (inject_range range) >|=
    List.map C.decode_string

  let exists_key ks k = exists_key ks table (C.encode_to_string k)
  let exists_keys ks l = exist_keys ks table (List.map C.encode_to_string l)
  let count_keys ks range = count_keys ks table (inject_range range)

  let get_slice ks ?max_keys ?max_columns ?decode_timestamps
        key_range ?predicate col_range =
    lwt k, data =
      get_slice ks table ?max_keys ?max_columns ?decode_timestamps
        (inject_range key_range) ?predicate col_range
    in
      return (Option.map C.decode_string k,
              List.map
                (fun kd -> { kd with key = C.decode_string kd.key })
                data)

  let get_bson_slice ks ?max_keys ?max_columns ?decode_timestamps
        key_range ?predicate col_range =
    lwt k, data =
      get_bson_slice ks table ?max_keys ?max_columns ?decode_timestamps
        (inject_range key_range) ?predicate col_range
    in
      return (Option.map C.decode_string k,
              List.map
                (fun kd -> { kd with key = C.decode_string kd.key })
                data)

  let get_row = match M.row_of_key_data with
      `Raw f ->
        (fun ks key ->
           match_lwt get_slice ks ~decode_timestamps:M.row_needs_timestamps
             (`Discrete [key]) `All
           with
               _, kd :: _ -> return (f kd)
             | _ -> return None)
    | `BSON f ->
        (fun ks key ->
           match_lwt get_bson_slice ks ~decode_timestamps:M.row_needs_timestamps
             (`Discrete [key]) `All
           with
               _, kd :: _ -> return (f kd)
             | _ -> return None)

  let get_rows = match M.row_of_key_data with
      `Raw f ->
        (fun ks ?max_keys key_range ->
           lwt k, l = get_slice ks key_range ?max_keys
                        ~decode_timestamps:M.row_needs_timestamps `All
           in return (k, List.filter_map f l))
    | `BSON f ->
        (fun ks ?max_keys key_range ->
           lwt k, l = get_bson_slice ks key_range ?max_keys
                        ~decode_timestamps:M.row_needs_timestamps `All
           in return (k, List.filter_map f l))

  let get_slice_values ks ?max_keys key_range cols =
    lwt k, l =
      get_slice_values ks table ?max_keys (inject_range key_range) cols
    in
      return (Option.map C.decode_string k,
              List.map (fun (k, cols) -> C.decode_string k, cols) l)

  let get_slice_values_with_timestamps ks ?max_keys key_range cols =
    lwt k, l =
      get_slice_values_with_timestamps ks table ?max_keys
        (inject_range key_range) cols
    in
      return (Option.map C.decode_string k,
              List.map (fun (k, cols) -> C.decode_string k, cols) l)

  let get_columns ks ?max_columns ?decode_timestamps key crange =
    get_columns ks table ?max_columns ?decode_timestamps
      (C.encode_to_string key) crange

  let get_column_values ks key cols =
    get_column_values ks table (C.encode_to_string key) cols

  let get_column ks key col = get_column ks table (C.encode_to_string key) col

  let put_columns ks key cols = put_columns ks table (C.encode_to_string key) cols

  let put_multi_columns ks l =
    put_multi_columns ks table
      (List.map (fun (k, cols) -> (C.encode_to_string k, cols)) l)

  let get_bson_slice_values ks ?max_keys key_range cols =
    lwt k, l =
      get_bson_slice_values ks table ?max_keys (inject_range key_range) cols
    in
      return (Option.map C.decode_string k,
              List.map (fun (k, cols) -> C.decode_string k, cols) l)

  let get_bson_slice_values_with_timestamps ks ?max_keys key_range cols =
    lwt k, l =
      get_bson_slice_values_with_timestamps ks table ?max_keys
        (inject_range key_range) cols
    in
      return (Option.map C.decode_string k,
              List.map (fun (k, cols) -> C.decode_string k, cols) l)

  let get_bson_columns ks ?max_columns ?decode_timestamps key crange =
    get_bson_columns ks table ?max_columns ?decode_timestamps
      (C.encode_to_string key) crange

  let get_bson_column_values ks key cols =
    get_bson_column_values ks table (C.encode_to_string key) cols

  let get_bson_column ks key col = get_bson_column ks table (C.encode_to_string key) col

  let put_bson_columns ks key cols = put_bson_columns ks table (C.encode_to_string key) cols

  let put_multi_bson_columns ks l =
    put_multi_bson_columns ks table
      (List.map (fun (k, cols) -> (C.encode_to_string k, cols)) l)

  let delete_columns ks key cols =
    delete_columns ks table (C.encode_to_string key) cols

  let delete_key ks key = delete_key ks table (C.encode_to_string key)

  let delete_keys ks key_range = delete_keys ks table (inject_range key_range)

  let watch_keys ks keys =
    watch_keys ks table (List.map C.encode_to_string keys)

  let watch_prefixes ks f prefixes =
    let codec = f C.codec in
      watch_prefixes ks table
        (List.map (Obs_key_encoding.encode_to_string codec) prefixes)

  let watch_columns ks l =
    watch_columns ks table (List.map (fun (k, l) -> (C.encode_to_string k, l)) l)
end
