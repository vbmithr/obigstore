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

(** Order-preserving key encoding. *)

(** This module provides functions that encode/decode values into/from
  * byte sequences while preserving the ordering of the original values, i.e.,
  * given two values [x] and [y] and noting the result of the encoding process
  * [enc x] and [enc y] respectively, then, without loss of generality:
  * * [x = y] implies [enc x = enc y]
  * * [x < y] implies [enc x < enc y]
  *)

type error =
    Unsatisfied_constraint of string
  | Incomplete_fragment of string
  | Bad_encoding of string
  | Unknown_tag of int

exception Error of error * string


(** [(_, 'a, _) codec] is a codec for values of type ['a]. *)
type ('internal, 'a, 'parts) codec

(** Codec for primitive types. *)
type 'a primitive_codec = ('a, 'a, unit) codec

(** Internal type. *)
type ('a, 'b, 'ma, 'mb, 'ta, 'tb) cons =
    ('a, 'ma, 'ta) codec * ('b, 'mb, 'tb) codec

(** {2 Encoding/decoding} *)

(** [encode codec b x] appends to the buffer [b] a byte sequence representing
  * [x] according to the [codec].
  * @raise Error(Unsatisfied_constraint _, _) if [x] doesn't satisfy a
  * constraint imposed by [codec]. *)
val encode : (_, 'a, _) codec -> Obs_bytea.t -> 'a -> unit

(** Similar to {!encode}, but directly returning a string. *)
val encode_to_string : (_, 'a, _) codec -> 'a -> string

(** [decode codec s off len scratch] returns the value corresponding to the byte
  * sequence in [s] starting at [off] and whose length is at most [len].
  * @param scratch scratch buffer that might be used to perform decoding.
  * @raise Invalid_arg if [off], [len] don't represent a valid substring of
  * [s].
  * @raise Error((Incomplete_fragment _ | Bad_encoding _), _) if the byte
  * sequence cannot be decoded correctly. *)
val decode :
  (_, 'a, _) codec -> string -> off:int -> len:int -> Obs_bytea.t -> 'a

(** Similar to {!decode}. *)
val decode_string : (_, 'a, _) codec -> string -> 'a

(** {2 Operations on values.} *)

val pp_value : (_, 'a, _) codec -> 'a -> string

(** Synomym for {!!pp_value}. *)
val pp : (_, 'a, _) codec -> 'a -> string

val min_value : (_, 'a, _) codec -> 'a
val max_value : (_, 'a, _) codec -> 'a

(** Saturating successor: returns the max if the value is already the max. *)
val succ_value : (_, 'a, _) codec -> 'a -> 'a

(** Saturating predecessor: returns the min if the value is already the min. *)
val pred_value : (_, 'a, _) codec -> 'a -> 'a

(** {3 Operations with immutable prefix} *)

(** {4 Lower bounds} *)

(** [lower5 c x] gives the lower bound for values that have the same 5-ary
  * prefix as [x].
  *
  * Given n types [t1, t2, ..., tn] whose values have correspondingly
  * [m1, m2, ..., mn] as their minimum values and [M1, M2, ..., Mn] as their
  * maximum ones, a codec [c] whose internal type is the tuple
  * [t1 * (t2 * (... * (tn-1 * tn)))], and a value [x] whose internal
  * representation according to [c] is [(x1, (x2, ... (xn-1, xn)))],
  * [lower5 c x] returns a value corresponding to the internal n-tuple
  * [(x1, (x2, (x3, (x4, (x5, (m6, ... (mn-1, mn)))))))].
  *
  * E.g., for given a codec
  * [let c = byte *** byte *** byte *** byte *** byte *** byte],
  * [lower5 c (0, (1, (2, (3, (4, 5))))) = (0, (1, (2, (3, (4, 0)))))].
  * *)
val lower5 :
  ('a * ('b * ('c * ('d * ('e * 'f)))), 'g,
   ('h, 'b * 'i, 'j, 'k, 'l,
    ('m, 'c * 'n, 'o, 'p, 'q,
     ('r, 'd * 's, 't, 'u, 'v,
      ('w, 'e * 'f, 'x, 'y, 'z, ('e, 'f, 'a1, 'b1, 'c1, 'd1) cons) cons)
     cons)
    cons)
   cons)
  codec -> 'g -> 'g

(** Refer to {!lower5}. *)
val lower4 :
  ('a * ('b * ('c * ('d * 'e))), 'f,
   ('g, 'b * 'h, 'i, 'j, 'k,
    ('l, 'c * 'm, 'n, 'o, 'p,
     ('q, 'd * 'e, 'r, 's, 't, ('d, 'e, 'u, 'v, 'w, 'x) cons) cons)
    cons)
   cons)
  codec -> 'f -> 'f

(** Refer to {!lower5}. *)
val lower3 :
  ('a * ('b * ('c * 'd)), 'e,
   ('f, 'b * 'g, 'h, 'i, 'j,
    ('k, 'c * 'd, 'l, 'm, 'n, ('c, 'd, 'o, 'p, 'q, 'r) cons) cons)
   cons)
  codec -> 'e -> 'e

(** Refer to {!lower5}. *)
val lower2 :
  ('a * ('b * 'c), 'd,
   ('e, 'b * 'c, 'f, 'g, 'h, ('b, 'c, 'i, 'j, 'k, 'l) cons) cons)
  codec -> 'd -> 'd

(** Refer to {!lower5}. *)
val lower1 : ('a * 'b, 'c, ('a, 'b, 'd, 'e, 'f, 'g) cons) codec -> 'c -> 'c

(** {4 Upper bounds} *)

(** [upper5 c x] gives the upper bound for values that have the same 5-ary
  * prefix as [x].
  *
  * Given n types [t1, t2, ..., tn] whose values have correspondingly
  * [m1, m2, ..., mn] as their minimum values and [M1, M2, ..., Mn] as their
  * maximum ones, a codec [c] whose internal type is the tuple
  * [t1 * (t2 * (... * (tn-1 * tn)))], and a value [x] whose internal
  * representation according to [c] is [(x1, (x2, ... (xn-1, xn)))],
  * [upper5 c x] returns a value corresponding to the internal n-tuple
  * [(x1, (x2, (x3, (x4, (x5, (M6, ... (Mn-1, Mn)))))))].
  *
  * E.g., for given a codec
  * [let c = byte *** byte *** byte *** byte *** byte *** byte],
  * [upper5 c (0, (1, (2, (3, (4, 5))))) = (0, (1, (2, (3, (4, 255)))))]
  * and
  * [upper4 c (0, (1, (2, (3, (4, 5))))) = (0, (1, (2, (3, (255, 255)))))].
  * *)
val upper5 :
  ('a * ('b * ('c * ('d * ('e * 'f)))), 'g,
   ('h, 'b * 'i, 'j, 'k, 'l,
    ('m, 'c * 'n, 'o, 'p, 'q,
     ('r, 'd * 's, 't, 'u, 'v,
      ('w, 'e * 'f, 'x, 'y, 'z, ('e, 'f, 'a1, 'b1, 'c1, 'd1) cons) cons)
     cons)
    cons)
   cons)
  codec -> 'g -> 'g

(** Refer to {!upper5}. *)
val upper4 :
  ('a * ('b * ('c * ('d * 'e))), 'f,
   ('g, 'b * 'h, 'i, 'j, 'k,
    ('l, 'c * 'm, 'n, 'o, 'p,
     ('q, 'd * 'e, 'r, 's, 't, ('d, 'e, 'u, 'v, 'w, 'x) cons) cons)
    cons)
   cons)
  codec -> 'f -> 'f

(** Refer to {!upper5}. *)
val upper3 :
  ('a * ('b * ('c * 'd)), 'e,
   ('f, 'b * 'g, 'h, 'i, 'j,
    ('k, 'c * 'd, 'l, 'm, 'n, ('c, 'd, 'o, 'p, 'q, 'r) cons) cons)
   cons)
  codec -> 'e -> 'e

(** Refer to {!upper5}. *)
val upper2 :
  ('a * ('b * 'c), 'd,
   ('e, 'b * 'c, 'f, 'g, 'h, ('b, 'c, 'i, 'j, 'k, 'l) cons) cons)
  codec -> 'd -> 'd

(** Refer to {!upper5}. *)
val upper1 : ('a * 'b, 'c, ('a, 'b, 'd, 'e, 'f, 'g) cons) codec -> 'c -> 'c

(** {4 Prefix expansion} *)

(** {5 CPS-style interface} *)

(** [expand] is used to expand a given prefix to the full length of the value
  * according to the provided codec, by appending a suffix with either the
  * maximum or the minimum values for each part; e.g.,
  *
  * {[
  *    expand
  *      (part 1 @@ part "foo" @@ max_suffix)
  *      (tuple4 byte stringz byte byte) = (1, "foo", 255, 255)
  *
  *    expand (part 1 @@ min_suffix) (byte *** positive_int64) = (1, 0L)
  * ]}
  * *)
val expand : (('a, 'b, 'c) codec -> 'a) -> ('a, 'b, 'c) codec -> 'b

(** {! Refer to {!expand}. *)
val ( @@ ) : ('a -> 'b) -> 'a -> 'b

(** {! Refer to {!expand}. *)
val part :
  'a -> (('b, 'c, 'd) codec -> 'e) ->
  ('f, 'g, ('h, 'b, 'a, 'c, 'i, 'd) cons) codec -> 'h * 'e

(** {! Refer to {!expand}. *)
val max_suffix : ('a, 'b, 'c) codec -> 'a

(** {! Refer to {!expand}. *)
val min_suffix : ('a, 'b, 'c) codec -> 'a

(** prefixN can be used to create composable prefixes; e.g.,
  * {[
  *    let prefix = prefix2 ("foo", 42) in
  *    (* alternatively:
  *     *  let prefix last = part "foo" @@ last 42 in
  *     * *)
  *    let lower = expand (prefix min_suffix) codec in
  *    let upper = expand (prefix max_suffix) codec in
  *      ...
  * ]}
  *
  * *)
val prefix1 : 'a -> ('a -> 'b) -> 'b

(** Refer to {!prefix1}. *)
val prefix2 :
  'a * 'b ->
  ('b -> ('c, 'd, 'e) codec -> 'f) ->
  ('g, 'h, ('i, 'c, 'a, 'd, 'j, 'e) cons) codec -> 'i * 'f

(** Refer to {!prefix1}. *)
val prefix3 :
  'a * 'b * 'c ->
  ('c -> ('d, 'e, 'f) codec -> 'g) ->
  ('h, 'i, ('j, 'k, 'a, 'l, 'm, ('n, 'd, 'b, 'e, 'o, 'f) cons) cons) codec ->
  'j * ('n * 'g)

(** Refer to {!prefix1}. *)
val prefix4 :
  'a * 'b * 'c * 'd ->
  ('d -> ('e, 'f, 'g) codec -> 'h) ->
  ('i, 'j,
   ('k, 'l, 'a, 'm, 'n,
    ('o, 'p, 'b, 'q, 'r, ('s, 'e, 'c, 'f, 't, 'g) cons) cons)
   cons)
  codec -> 'k * ('o * ('s * 'h))

(** Refer to {!prefix1}. *)
val prefix5 :
  'a * 'b * 'c * 'd * 'e ->
  ('e -> ('f, 'g, 'h) codec -> 'i) ->
  ('j, 'k,
   ('l, 'm, 'a, 'n, 'o,
    ('p, 'q, 'b, 'r, 's,
     ('t, 'u, 'c, 'v, 'w, ('x, 'f, 'd, 'g, 'y, 'h) cons) cons)
    cons)
   cons)
  codec -> 'l * ('p * ('t * ('x * 'i)))

(** {5 Direct-style interface} *)

(** [expand_max1 c x] takes takes a prefix [x] and expands it up to [c]'s
  * arity by appending the maximum values as defined by the codec.
  *
  * E.g.,
  *   [expand_max1 (byte *** byte) 42 = (42, 255)]
  * and
  *   [expand_max1 (tuple3 byte byte byte) 42 = (42, 255, 255)]
  * *)
val expand_max1 : ('a * 'b, 'c, ('a, 'b, 'd, _, _, _) cons) codec -> 'd -> 'c

(** Refer to {!expand_max1}. *)
val expand_max2 :
  ('a * ('b * 'c), 'd,
   ('a, ('b * 'c), 'f, _, _, ('b, 'c, 'i, _, _, _) cons) cons)
  codec -> 'f * 'i -> 'd

(** Refer to {!expand_max1}. *)
val expand_max3 :
  ('a * ('b * ('c * 'd)), 'e,
   ('a, ('b * ('c * 'd)), 'g, _, _,
    ('b, ('c * 'd), 'k, _, _, ('c, 'd, 'n, _, _, _) cons) cons)
   cons)
  codec -> 'g * 'k * 'n -> 'e

(** Refer to {!expand_max1}. *)
val expand_max4 :
  ('a * ('b * ('c * ('d * 'e))), 'f,
   ('a, ('b * ('c * ('d * 'e))), 'h, _, _,
    ('b, ('c * ('d * 'e)), 'l, _, _,
     ('c, ('d * 'e), 'p, _, _, ('d, 'e, 's, _, _, _) cons) cons)
    cons)
   cons)
  codec -> 'h * 'l * 'p * 's -> 'f

(** Refer to {!expand_max1}. *)
val expand_max5 :
  ('a * ('b * ('c * ('d * ('e * 'f)))), 'g,
   ('a, ('b * ('c * ('d * ('e * 'f)))), 'i, _, _,
    ('b, ('c * ('d * ('e * 'f))), 'm, _, _,
     ('c, ('d * ('e * 'f)), 'q, _, _,
      ('d, ('e * 'f), 'u, _, _, ('e, 'f, 'x, _, _, _) cons) cons)
     cons)
    cons)
   cons)
  codec -> 'i * 'm * 'q * 'u * 'x -> 'g

(** [expand_min1 c x] takes takes a prefix [x] and expands it up to [c]'s
  * arity by appending the minimum values as defined by the codec.
  *
  * E.g.,
  *   [expand_min1 (byte *** byte) 42 = (42, 0)]
  * and
  *   [expand_min1 (tuple3 byte byte byte) 42 = (42, 0, 0)]
  *)
val expand_min1 : ('a * 'b, 'c, ('a, 'b, 'd, _, _, _) cons) codec -> 'd -> 'c

(** Refer to {!expand_min1}. *)
val expand_min2 :
  ('a * ('b * 'c), 'd,
   ('a, ('b * 'c), 'f, _, _, ('b, 'c, 'i, _, _, _) cons) cons)
  codec -> 'f * 'i -> 'd

(** Refer to {!expand_min1}. *)
val expand_min3 :
  ('a * ('b * ('c * 'd)), 'e,
   ('a, ('b * ('c * 'd)), 'g, _, _,
    ('b, ('c * 'd), 'k, _, _, ('c, 'd, 'n, _, _, _) cons) cons)
   cons)
  codec -> 'g * 'k * 'n -> 'e

(** Refer to {!expand_min1}. *)
val expand_min4 :
  ('a * ('b * ('c * ('d * 'e))), 'f,
   ('a, ('b * ('c * ('d * 'e))), 'h, _, _,
    ('b, ('c * ('d * 'e)), 'l, _, _,
     ('c, ('d * 'e), 'p, _, _, ('d, 'e, 's, _, _, _) cons) cons)
    cons)
   cons)
  codec -> 'h * 'l * 'p * 's -> 'f

(** Refer to {!expand_min1}. *)
val expand_min5 :
  ('a * ('b * ('c * ('d * ('e * 'f)))), 'g,
   ('a, ('b * ('c * ('d * ('e * 'f)))), 'i, _, _,
    ('b, ('c * ('d * ('e * 'f))), 'm, _, _,
     ('c, ('d * ('e * 'f)), 'q, _, _,
      ('d, ('e * 'f), 'u, _, _, ('e, 'f, 'x, _, _, _) cons) cons)
     cons)
    cons)
   cons)
  codec -> 'i * 'm * 'q * 'u * 'x -> 'g

(*+ {2 Codecs} *)

(** {3 Primitive codecs} *)

val self_delimited_string : string primitive_codec
val stringz : string primitive_codec
val stringz_unsafe : string primitive_codec
val positive_int64 : Int64.t primitive_codec
val byte : int primitive_codec
val bool : bool primitive_codec

(** Similar to {!positive_int64}, but with inverted order relative to the
  * natural order of [Int64.t] values, i.e.,
  * given [f = encode_to_string positive_int64_complement], if [x < y] then
  * [f x > f y]. *)
val positive_int64_complement : Int64.t primitive_codec

(** {3 Composite codecs} *)

(** [custom ~encode ~decode ~pp ?min ?max codec] creates a new codec which operates
  * internally with values of the type handled by [codec], but uses [encode] and
  * [decode] to convert to/from an external type, so that for instance
  * [encode (custom ~encode:enc ~decode:dec ~pp codec) b x]
  * is equivalent to  [encode codec b (enc x)], and
  * [decode_string (custom ~encode:enc ~decode:dec ~pp codec) s] is equivalent
  * to [dec (decode_string codec s)].
  *
  * If encode/decode are not bijective and the value mapping is only defined
  * in a range, [min] and [max] can be used to specify it.
  * *)
val custom :
  encode:('a -> 'c) ->
  decode:('c -> 'a) ->
  pp:('a -> string) ->
  ?min:'a -> ?max:'a -> ('b, 'c, 'd) codec -> ('b, 'a, 'd) codec

(** [tuple2 c1 c2] creates a new codec which operates on tuples whose 1st element
  * have the type handled by [c1] and whose 2nd element have the type handled
  * by [c2]. *)
val tuple2 :
  ('a, 'b, 'c) codec ->
  ('d, 'e, 'f) codec ->
  ('a * 'd, 'b * 'e, ('a, 'd, 'b, 'e, 'c, 'f) cons) codec

(** Synonym for {! tuple2}. *)
val ( *** ) :
  ('a, 'b, 'c) codec ->
  ('d, 'e, 'f) codec ->
  ('a * 'd, 'b * 'e, ('a, 'd, 'b, 'e, 'c, 'f) cons) codec

(** [tuple3 c1 c2 c3] creates a codec operating on 3-tuples with the types
  * corresponding to the values handled by codecs [c1], [c2] and [c3].
  * Operates similarly to [c1 *** c2 *** c3], but uses a customized
  * pretty-printer and functions to map/to from the internal representation.
  * *)
val tuple3 :
  ('a, 'b, 'c) codec ->
  ('d, 'e, 'f) codec ->
  ('g, 'h, 'i) codec ->
  ('a * ('d * 'g), 'b * 'e * 'h,
   ('a, 'd * 'g, 'b, 'e * 'h, 'c, ('d, 'g, 'e, 'h, 'f, 'i) cons) cons)
  codec

(** [tuple4 c1 c2 c3 c4] creates a codec operating on 4-tuples with the types
  * corresponding to the values handled by codecs [c1], [c2], [c3] and [c4]. *)
val tuple4 :
  ('a, 'b, 'c) codec ->
  ('d, 'e, 'f) codec ->
  ('g, 'h, 'i) codec ->
  ('j, 'k, 'l) codec ->
  ('a * ('d * ('g * 'j)), 'b * 'e * 'h * 'k,
   ('a, 'd * ('g * 'j), 'b, 'e * ('h * 'k), 'c,
    ('d, 'g * 'j, 'e, 'h * 'k, 'f, ('g, 'j, 'h, 'k, 'i, 'l) cons) cons)
   cons)
  codec

(** [tuple5 c1 c2 c3 c4 c5] creates a codec operating on 5-tuples with the
  * types corresponding to the values handled by codecs [c1], [c2], [c3], [c4]
  * and [c5]. *)
val tuple5 :
  ('a, 'b, 'c) codec ->
  ('d, 'e, 'f) codec ->
  ('g, 'h, 'i) codec ->
  ('j, 'k, 'l) codec ->
  ('m, 'n, 'o) codec ->
  ('a * ('d * ('g * ('j * 'm))), 'b * 'e * 'h * 'k * 'n,
   ('a, 'd * ('g * ('j * 'm)), 'b, 'e * ('h * ('k * 'n)), 'c,
    ('d, 'g * ('j * 'm), 'e, 'h * ('k * 'n), 'f,
     ('g, 'j * 'm, 'h, 'k * 'n, 'i, ('j, 'm, 'k, 'n, 'l, 'o) cons) cons)
    cons)
   cons)
  codec

(** [choice2 label1 c1 label2 c2] creates a codec that
  * handles values of type [`A of a | `B of b] where [a] and [b] are the types
  * of the values handled by codecs [c1] and [c2]. These values are encoded as
  * a one-byte tag (0 for [`A x] values, 1 for [`B x] values) followed by the
  * encoding corresponding to the codec used for that value.
  * [label1] and [label2] are only used in pretty-printing-related function. *)
val choice2 :
  string -> ('a, 'a, 'b) codec ->
  string -> ('c, 'c, 'd) codec ->
  ([ `A of 'a | `B of 'c ], [ `A of 'a | `B of 'c ], unit) codec

(** Refer to {!choice2}. *)
val choice3 :
  string -> ('a, 'a, 'b) codec ->
  string -> ('c, 'c, 'd) codec ->
  string -> ('e, 'e, 'f) codec ->
  ([ `A of 'a | `B of 'c | `C of 'e ], [ `A of 'a | `B of 'c | `C of 'e ],
   unit)
  codec

(** Refer to {!choice2}. *)
val choice4 :
  string -> ('a, 'a, 'b) codec ->
  string -> ('c, 'c, 'd) codec ->
  string -> ('e, 'e, 'f) codec ->
  string -> ('g, 'g, 'h) codec ->
  ([ `A of 'a | `B of 'c | `C of 'e | `D of 'g ],
   [ `A of 'a | `B of 'c | `C of 'e | `D of 'g ], unit)
  codec

(** Refer to {!choice2}. *)
val choice5 :
  string -> ('a, 'a, 'b) codec ->
  string -> ('c, 'c, 'd) codec ->
  string -> ('e, 'e, 'f) codec ->
  string -> ('g, 'g, 'h) codec ->
  string -> ('i, 'i, 'j) codec ->
  ([ `A of 'a | `B of 'c | `C of 'e | `D of 'g | `E of 'i ],
   [ `A of 'a | `B of 'c | `C of 'e | `D of 'g | `E of 'i ], unit)
  codec

(** {2 Codec prefix extraction} *)

(** [codec_prefix1 c] returns a codec which handles values whose type is that
  * of the first element of the tuple handled by [c]; e.g.,
  *   [codec_prefix1 (tuple2 byte bool)], is equivalent to [byte].
  * *)
val codec_prefix1 :
  ('a, 'b, ('c, 'd, 'e, 'f, 'g, 'h) cons) codec -> ('c, 'e, 'g) codec

(** Refer to {!codec_prefix1}. *)
val codec_prefix2 :
  ('a, 'b, ('c, 'd, 'e, 'f, 'g, ('h, 'i, 'j, 'k, 'l, 'm) cons) cons) codec ->
  ('c * 'h, 'e * 'j, ('c, 'h, 'e, 'j, 'g, 'l) cons) codec

(** Refer to {!codec_prefix1}. *)
val codec_prefix3 :
  ('a, 'b,
   ('c, 'd, 'e, 'f, 'g,
    ('h, 'i, 'j, 'k, 'l, ('m, 'n, 'o, 'p, 'q, 'r) cons) cons)
   cons)
  codec ->
  ('c * ('h * 'm), 'e * 'j * 'o,
   ('c, 'h * 'm, 'e, 'j * 'o, 'g, ('h, 'm, 'j, 'o, 'l, 'q) cons) cons)
  codec

(** Refer to {!codec_prefix1}. *)
val codec_prefix4 :
  ('a, 'b,
   ('c, 'd, 'e, 'f, 'g,
    ('h, 'i, 'j, 'k, 'l,
     ('m, 'n, 'o, 'p, 'q, ('r, 's, 't, 'u, 'v, 'w) cons) cons)
    cons)
   cons)
  codec ->
  ('c * ('h * ('m * 'r)), 'e * 'j * 'o * 't,
   ('c, 'h * ('m * 'r), 'e, 'j * ('o * 't), 'g,
    ('h, 'm * 'r, 'j, 'o * 't, 'l, ('m, 'r, 'o, 't, 'q, 'v) cons) cons)
   cons)
  codec

(** Refer to {!codec_prefix1}. *)
val codec_prefix5 :
  ('a, 'b,
   ('c, 'd, 'e, 'f, 'g,
    ('h, 'i, 'j, 'k, 'l,
     ('m, 'n, 'o, 'p, 'q,
      ('r, 's, 't, 'u, 'v, ('w, 'x, 'y, 'z, 'a1, 'b1) cons) cons)
     cons)
    cons)
   cons)
  codec ->
  ('c * ('h * ('m * ('r * 'w))), 'e * 'j * 'o * 't * 'y,
   ('c, 'h * ('m * ('r * 'w)), 'e, 'j * ('o * ('t * 'y)), 'g,
    ('h, 'm * ('r * 'w), 'j, 'o * ('t * 'y), 'l,
     ('m, 'r * 'w, 'o, 't * 'y, 'q, ('r, 'w, 't, 'y, 'v, 'a1) cons) cons)
    cons)
   cons)
  codec

(** {2 Modular interface} *)

module type CODEC =
sig
  type tail
  type internal_key
  type key
  val codec : (internal_key, key, tail) codec
end

module type CODEC_OPS =
sig
  include CODEC

  val min_value : key
  val max_value : key
  val pp : key -> string
  val pp_value : key -> string
  val succ_value : key -> key
  val pred_value : key -> key
  val encode : Obs_bytea.t -> key -> unit
  val encode_to_string : key -> string
  val decode : string -> off:int -> len:int -> Obs_bytea.t -> key
  val decode_string : string -> key
  val expand : ((internal_key, key, tail) codec -> internal_key) -> key
end

module type LABELED_CODEC =
sig
  type key
  include CODEC with type key := key and type internal_key = key

  val codec : (internal_key, key, tail) codec
  val label : string
end

module type PRIMITIVE_CODEC_OPS =
sig
  type key
  include CODEC_OPS with type key := key and type internal_key = key
                     and type tail = unit
end

module Bool : PRIMITIVE_CODEC_OPS with type key = bool
module Byte : PRIMITIVE_CODEC_OPS with type key = int
module Positive_int64 : PRIMITIVE_CODEC_OPS with type key = Int64.t
module Positive_int64_complement : PRIMITIVE_CODEC_OPS with type key = Int64.t
module Stringz : PRIMITIVE_CODEC_OPS with type key = string
module Stringz_unsafe : PRIMITIVE_CODEC_OPS with type key = string
module Self_delimited_string : PRIMITIVE_CODEC_OPS with type key = string

module Custom :
  functor (C : CODEC) ->
  functor
    (O : sig
           type key
           val encode : key -> C.key
           val decode : C.key -> key
           val pp : key -> string

           (**  Set to [Some min] if the default range (obtained by revere mapping
             * the range of the original codec with [decode]) is not valid. *)
           val min : key option
           val max : key option
         end) ->
  CODEC_OPS with type key = O.key
             and type internal_key = C.internal_key
             and type tail = C.tail

module Tuple2 :
  functor (C1 : CODEC) ->
  functor (C2 : CODEC) ->
  CODEC_OPS
    with type key = C1.key * C2.key
     and type internal_key = C1.internal_key * C2.internal_key
     and type tail = (C1.internal_key, C2.internal_key, C1.key, C2.key, C1.tail,
                      C2.tail) cons

module Tuple3 :
  functor (C1 : CODEC) ->
  functor (C2 : CODEC) ->
  functor (C3 : CODEC) ->
  CODEC_OPS
    with type key = C1.key * C2.key * C3.key
     and type internal_key =
                C1.internal_key * (C2.internal_key * C3.internal_key)
     and type tail =
                (C1.internal_key, C2.internal_key * C3.internal_key, C1.key,
                 C2.key * C3.key, C1.tail,
                 (C2.internal_key, C3.internal_key, C2.key, C3.key, C2.tail,
                  C3.tail)
                 cons)
                cons

module Tuple4 :
  functor (C1 : CODEC) ->
  functor (C2 : CODEC) ->
  functor (C3 : CODEC) ->
  functor (C4 : CODEC) ->
  CODEC_OPS
    with type key = C1.key * C2.key * C3.key * C4.key
     and type internal_key =
                C1.internal_key *
                (C2.internal_key * (C3.internal_key * C4.internal_key))
     and type tail =
           (C1.internal_key,
            C2.internal_key * (C3.internal_key * C4.internal_key),
            C1.key, C2.key * (C3.key * C4.key), C1.tail,
            (C2.internal_key, C3.internal_key * C4.internal_key,
             C2.key, C3.key * C4.key, C2.tail,
             (C3.internal_key, C4.internal_key, C3.key, C4.key,
              C3.tail, C4.tail)
             cons)
            cons)
           cons

module Tuple5 :
  functor (C1 : CODEC) ->
  functor (C2 : CODEC) ->
  functor (C3 : CODEC) ->
  functor (C4 : CODEC) ->
  functor (C5 : CODEC) ->
  CODEC_OPS
    with type key = C1.key * C2.key * C3.key * C4.key * C5.key
     and type internal_key =
                C1.internal_key *
                (C2.internal_key *
                 (C3.internal_key * (C4.internal_key * C5.internal_key)))
     and type tail =
                (C1.internal_key,
                 C2.internal_key *
                 (C3.internal_key * (C4.internal_key * C5.internal_key)),
                 C1.key, C2.key * (C3.key * (C4.key * C5.key)), C1.tail,
                 (C2.internal_key,
                  C3.internal_key * (C4.internal_key * C5.internal_key),
                  C2.key, C3.key * (C4.key * C5.key), C2.tail,
                  (C3.internal_key, C4.internal_key * C5.internal_key,
                   C3.key, C4.key * C5.key, C3.tail,
                   (C4.internal_key, C5.internal_key, C4.key, C5.key,
                    C4.tail, C5.tail)
                   cons)
                  cons)
                 cons)
                cons

module Choice2 :
  functor (C1 : LABELED_CODEC) ->
  functor (C2 : LABELED_CODEC) ->
  PRIMITIVE_CODEC_OPS
    with type key = [ `A of C1.key | `B of C2.key ]

module Choice3 :
  functor (C1 : LABELED_CODEC) ->
  functor (C2 : LABELED_CODEC) ->
  functor (C3 : LABELED_CODEC) ->
  PRIMITIVE_CODEC_OPS
    with type key = [ `A of C1.key | `B of C2.key | `C of C3.key]

module Choice4 :
  functor (C1 : LABELED_CODEC) ->
  functor (C2 : LABELED_CODEC) ->
  functor (C3 : LABELED_CODEC) ->
  functor (C4 : LABELED_CODEC) ->
  PRIMITIVE_CODEC_OPS
    with type key = [ `A of C1.key | `B of C2.key | `C of C3.key | `D of C4.key]

module Choice5 :
  functor (C1 : LABELED_CODEC) ->
  functor (C2 : LABELED_CODEC) ->
  functor (C3 : LABELED_CODEC) ->
  functor (C4 : LABELED_CODEC) ->
  functor (C5 : LABELED_CODEC) ->
  PRIMITIVE_CODEC_OPS
    with type key = [ `A of C1.key | `B of C2.key | `C of C3.key | `D of C4.key
                    | `E of C5.key]
