
type db
type keyspace

(** {2 Type definitions} *)

module Data :
sig
  type table = string

  type key = string

  type column = { name : column_name; data : string; timestamp : timestamp; }

  and column_name = string

  and timestamp = No_timestamp | Timestamp of Int64.t

  type key_data = { key : key; last_column : string option; columns : column list }

  type slice = key option * key_data list (** last_key * data *)

  type range =
    {
      first : string option;
      up_to : string option;
    }

  type key_range =
      Key_range of range
    | Keys of string list

  type column_range =
      All_columns
    | Columns of string list
end

module Update :
sig
  type column_data = { name : Data.column_name; data : string;
                       timestamp : timestamp }

  and timestamp = No_timestamp | Auto_timestamp | Timestamp of Int64.t
end

val open_db : string -> db
val close_db : db -> unit
val list_keyspaces : db -> string list
val register_keyspace : db -> string -> keyspace
val get_keyspace : db -> string -> keyspace option

val keyspace_name : keyspace -> string

val list_tables : keyspace -> Data.table list

(** {2 Transactions} *)
type transaction

val read_committed_transaction :
  keyspace -> (transaction -> 'a Lwt.t) -> 'a Lwt.t

val repeatable_read_transaction :
  keyspace -> (transaction -> 'a Lwt.t) -> 'a Lwt.t

(** {2 Read operations} *)

val get_keys_in_range :
  transaction -> Data.table ->
  ?max_keys:int ->
  Data.key_range -> string list Lwt.t

val get_slice :
  transaction -> Data.table ->
  ?max_keys:int ->
  Data.key_range -> Data.column_range -> Data.slice Lwt.t

val get_columns :
  transaction -> Data.table ->
  ?max_columns:int ->
  Data.key -> Data.column_range ->
  (Data.column_name * Data.column list) option Lwt.t

val get_column :
  transaction -> Data.table ->
  Data.key -> Data.column_name -> (string * Data.timestamp) option Lwt.t

(** Write operations *)

val put_columns :
  transaction -> Data.table -> Data.key -> Update.column_data list ->
  unit Lwt.t

val delete_columns :
  transaction -> Data.table -> Data.key -> Data.column_name list -> unit Lwt.t

val delete_key : transaction -> Data.table -> Data.key -> unit Lwt.t
