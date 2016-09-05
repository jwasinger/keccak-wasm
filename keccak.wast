;;
;; Keccak-256 (pre-standard SHA3) implementation in WASM
;;
;; Main entry point is $KECCAK which has 4 parameters:
;; - context offset (i32) -> 792 bytes
;; - input offset (i32)
;; - input length (i32)
;; - output offset (i32) -> 32 byte hash
;;
;; The context is laid out as follows:
;;   0: 1600 bits - 200 bytes - hashing state
;; 200:   64 bits -   8 bytes - residue position
;; 208: 1536 bits - 192 bytes - residue buffer
;; 400: 1536 bits - 192 bytes - round constants
;; 592: 1600 bits - 200 bytes - rotation constants
;;
;; --
;;
;; Specification at: http://keccak.noekeon.org/specs_summary.html
;;
;; This implementation is based on https://github.com/rhash/RHash/blob/master/librhash/sha3.c
;;
;; Most of the methods are fully unrolled.  Would be much nicer with macros, hopefully this
;; gets implemented: https://github.com/WebAssembly/sexpr-wasm-prototype/issues/92
;;

(func $KECCAK_THETA
  (param $context_offset i32)

  (local $C0 i64)
  (local $C1 i64)
  (local $C2 i64)
  (local $C3 i64)
  (local $C4 i64)
  (local $D0 i64)
  (local $D1 i64)
  (local $D2 i64)
  (local $D3 i64)
  (local $D4 i64)

  ;; C[x] = A[x] ^ A[x + 5] ^ A[x + 10] ^ A[x + 15] ^ A[x + 20];
  (set_local $C0
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 0)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.const 40)))
        (i64.xor
          (i64.load (i32.add (get_local $context_offset) (i32.const 80)))
          (i64.xor
            (i64.load (i32.add (get_local $context_offset) (i32.const 120)))
            (i64.load (i32.add (get_local $context_offset) (i32.const 160)))
          )
        )
      )
    )
  )

  (set_local $C1
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 8)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.const 48)))
        (i64.xor
          (i64.load (i32.add (get_local $context_offset) (i32.const 88)))
          (i64.xor
            (i64.load (i32.add (get_local $context_offset) (i32.const 128)))
            (i64.load (i32.add (get_local $context_offset) (i32.const 168)))
          )
        )
      )
    )
  )

  (set_local $C2
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 16)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.const 56)))
        (i64.xor
          (i64.load (i32.add (get_local $context_offset) (i32.const 96)))
          (i64.xor
            (i64.load (i32.add (get_local $context_offset) (i32.const 136)))
            (i64.load (i32.add (get_local $context_offset) (i32.const 176)))
          )
        )
      )
    )
  )

  (set_local $C3
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 24)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.const 64)))
        (i64.xor
          (i64.load (i32.add (get_local $context_offset) (i32.const 104)))
          (i64.xor
            (i64.load (i32.add (get_local $context_offset) (i32.const 144)))
            (i64.load (i32.add (get_local $context_offset) (i32.const 184)))
          )
        )
      )
    )
  )

  (set_local $C4
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 32)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.const 72)))
        (i64.xor
          (i64.load (i32.add (get_local $context_offset) (i32.const 112)))
          (i64.xor
            (i64.load (i32.add (get_local $context_offset) (i32.const 152)))
            (i64.load (i32.add (get_local $context_offset) (i32.const 192)))
          )
        )
      )
    )
  )

  ;; D[0] = ROTL64(C[1], 1) ^ C[4];
  (set_local $D0
    (i64.xor
      (get_local $C4)
      (i64.rotl
        (get_local $C1)
        (i64.const 1)
      )
    )
  )

  ;; D[1] = ROTL64(C[2], 1) ^ C[0];
  (set_local $D1
    (i64.xor
      (get_local $C0)
      (i64.rotl
        (get_local $C2)
        (i64.const 1)
      )
    )
  )

  ;; D[2] = ROTL64(C[3], 1) ^ C[1];
  (set_local $D2
    (i64.xor
      (get_local $C1)
      (i64.rotl
        (get_local $C3)
        (i64.const 1)
      )
    )
  )

  ;; D[3] = ROTL64(C[4], 1) ^ C[2];
  (set_local $D3
    (i64.xor
      (get_local $C2)
      (i64.rotl
        (get_local $C4)
        (i64.const 1)
      )
    )
  )

  ;; D[4] = ROTL64(C[0], 1) ^ C[3];
  (set_local $D4
    (i64.xor
      (get_local $C3)
      (i64.rotl
        (get_local $C0)
        (i64.const 1)
      )
    )
  )

  ;; A[x]      ^= D[x];
  ;; A[x + 5]  ^= D[x];
  ;; A[x + 10] ^= D[x];
  ;; A[x + 15] ^= D[x];
  ;; A[x + 20] ^= D[x];
  
  ;; x = 0
  (i64.store (i32.add (get_local $context_offset) (i32.const 0))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 0)))
      (get_local $D0)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 40))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 40)))
      (get_local $D0)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 80))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 80)))
      (get_local $D0)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 120))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 120)))
      (get_local $D0)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 160))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 160)))
      (get_local $D0)
    )
  )

  ;; x = 1
  (i64.store (i32.add (get_local $context_offset) (i32.const 8))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 8)))
      (get_local $D1)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 48))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 48)))
      (get_local $D1)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 88))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 88)))
      (get_local $D1)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 128))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 128)))
      (get_local $D1)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 168))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 168)))
      (get_local $D1)
    )
  )

  ;; x = 2
  (i64.store (i32.add (get_local $context_offset) (i32.const 16))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 16)))
      (get_local $D2)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 56))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 56)))
      (get_local $D2)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 96))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 96)))
      (get_local $D2)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 136))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 136)))
      (get_local $D2)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 176))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 176)))
      (get_local $D2)
    )
  )

  ;; x = 3
  (i64.store (i32.add (get_local $context_offset) (i32.const 24))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 24)))
      (get_local $D3)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 64))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 64)))
      (get_local $D3)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 104))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 104)))
      (get_local $D3)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 144))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 144)))
      (get_local $D3)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 184))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 184)))
      (get_local $D3)
    )
  )

  ;; x = 4
  (i64.store (i32.add (get_local $context_offset) (i32.const 32))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 32)))
      (get_local $D4)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 72))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 72)))
      (get_local $D4)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 112))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 112)))
      (get_local $D4)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 152))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 152)))
      (get_local $D4)
    )
  )

  (i64.store (i32.add (get_local $context_offset) (i32.const 192))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 192)))
      (get_local $D4)
    )
  )
)

(func $KECCAK_RHO
  (param $context_offset i32)
  (param $rotation_consts i32)

  ;;(local $tmp i32)

  ;; state[ 1] = ROTL64(state[ 1],  1);
  ;;(set_local $tmp (i32.add (get_local $context_offset) (i32.const 1)))
  ;;(i64.store (get_local $tmp) (i64.rotl (i64.load (get_local $context_offset)) (i64.const 1)))

  ;;(set_local $tmp (i32.add (get_local $context_offset) (i32.const 2)))
  ;;(i64.store (get_local $tmp) (i64.rotl (i64.load (get_local $context_offset)) (i64.const 62)))

  (local $tmp i32)
  (local $i i32)

  ;; for (i = 0; i <= 24; i++)
  (set_local $i (i32.const 0))
  (loop $done $loop
    (if (i32.ge_u (get_local $i) (i32.const 24))
      (br $done)
    )

    (set_local $tmp (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (i32.const 1) (get_local $i)))))

    (i64.store (get_local $tmp) (i64.rotl (i64.load (get_local $tmp)) (i64.load (i32.add (get_local $rotation_consts) (i32.mul (i32.const 8) (get_local $i))))))

    (set_local $i (i32.add (get_local $i) (i32.const 1)))
    (br $loop)
  )
)

(func $KECCAK_PI
  (param $context_offset i32)

  (local $A1 i64)
  (set_local $A1 (i64.load (i32.add (get_local $context_offset) (i32.const 8))))

  ;; Swap non-overlapping fields, i.e. $A1 = $A6, etc.
  ;; NOTE: $A0 is untouched
  (i64.store (i32.add (get_local $context_offset) (i32.const 8)) (i64.load (i32.add (get_local $context_offset) (i32.const 48))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 48)) (i64.load (i32.add (get_local $context_offset) (i32.const 72))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 72)) (i64.load (i32.add (get_local $context_offset) (i32.const 176))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 176)) (i64.load (i32.add (get_local $context_offset) (i32.const 112))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 112)) (i64.load (i32.add (get_local $context_offset) (i32.const 160))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 160)) (i64.load (i32.add (get_local $context_offset) (i32.const 16))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 16)) (i64.load (i32.add (get_local $context_offset) (i32.const 96))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 96)) (i64.load (i32.add (get_local $context_offset) (i32.const 104))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 104)) (i64.load (i32.add (get_local $context_offset) (i32.const 152))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 152)) (i64.load (i32.add (get_local $context_offset) (i32.const 184))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 184)) (i64.load (i32.add (get_local $context_offset) (i32.const 120))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 120)) (i64.load (i32.add (get_local $context_offset) (i32.const 32))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 32)) (i64.load (i32.add (get_local $context_offset) (i32.const 192))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 192)) (i64.load (i32.add (get_local $context_offset) (i32.const 168))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 168)) (i64.load (i32.add (get_local $context_offset) (i32.const 64))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 64)) (i64.load (i32.add (get_local $context_offset) (i32.const 128))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 128)) (i64.load (i32.add (get_local $context_offset) (i32.const 40))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 40)) (i64.load (i32.add (get_local $context_offset) (i32.const 24))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 24)) (i64.load (i32.add (get_local $context_offset) (i32.const 144))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 144)) (i64.load (i32.add (get_local $context_offset) (i32.const 136))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 136)) (i64.load (i32.add (get_local $context_offset) (i32.const 88))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 88)) (i64.load (i32.add (get_local $context_offset) (i32.const 56))))
  (i64.store (i32.add (get_local $context_offset) (i32.const 56)) (i64.load (i32.add (get_local $context_offset) (i32.const 80))))

  ;; Place the previously saved overlapping field
  (i64.store (i32.add (get_local $context_offset) (i32.const 80)) (get_local $A1))
)

(func $KECCAK_CHI
  (param $context_offset i32)

  (local $A0 i64)
  (local $A1 i64)
  (local $i i32)

  ;; for (round = 0; round < 25; i += 5)
  (set_local $i (i32.const 0))
  (loop $done $loop
    (if (i32.ge_u (get_local $i) (i32.const 25))
      (br $done)
    )

    (set_local $A0 (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (get_local $i)))))
    (set_local $A1 (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 1))))))

    ;; A[0 + i] ^= ~A1 & A[2 + i];
    (i64.store (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (get_local $i)))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (get_local $i))))
        (i64.and
          (i64.xor (get_local $A1) (i64.const 0xFFFFFFFFFFFFFFFF)) ;; bitwise not
          (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 2)))))
        )
      )
    )

    ;; A[1 + i] ^= ~A[2 + i] & A[3 + i];
    (i64.store (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 1))))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 1)))))
        (i64.and
          (i64.xor (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 2))))) (i64.const 0xFFFFFFFFFFFFFFFF)) ;; bitwise not
          (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 3)))))
        )
      )
    )

    ;; A[2 + i] ^= ~A[3 + i] & A[4 + i];
    (i64.store (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 2))))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 2)))))
        (i64.and
          (i64.xor (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 3))))) (i64.const 0xFFFFFFFFFFFFFFFF)) ;; bitwise not
          (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 4)))))
        )
      )
    )

    ;; A[3 + i] ^= ~A[4 + i] & A0;
    (i64.store (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 3))))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 3)))))
        (i64.and
          (i64.xor (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 4))))) (i64.const 0xFFFFFFFFFFFFFFFF)) ;; bitwise not
          (get_local $A0)
        )
      )
    )

    ;; A[4 + i] ^= ~A0 & A1;
    (i64.store (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 4))))
      (i64.xor
        (i64.load (i32.add (get_local $context_offset) (i32.mul (i32.const 8) (i32.add (get_local $i) (i32.const 4)))))
        (i64.and
          (i64.xor (get_local $A0) (i64.const 0xFFFFFFFFFFFFFFFF)) ;; bitwise not
          (get_local $A1)
        )
      )
    )

    (set_local $i (i32.add (get_local $i) (i32.const 5)))
    (br $loop)
  )
)

(func $KECCAK_PERMUTE
  (param $context_offset i32)

  (local $rotation_consts i32)
  (local $round_consts i32)
  (local $round i32)

  (set_local $round_consts (i32.add (get_local $context_offset) (i32.const 400)))
  (set_local $rotation_consts (i32.add (get_local $context_offset) (i32.const 592)))

  ;; for (round = 0; round < 24; round++)
  (set_local $round (i32.const 0))
  (loop $done $loop
    (if (i32.ge_u (get_local $round) (i32.const 24))
      (br $done)
    )

    ;; theta transform
    (call $KECCAK_THETA (get_local $context_offset))

    ;; rho transform
    (call $KECCAK_RHO (get_local $context_offset) (get_local $rotation_consts))

    ;; pi transform
    (call $KECCAK_PI (get_local $context_offset))

    ;; chi transform
    (call $KECCAK_CHI (get_local $context_offset))

    ;; iota transform
    ;; context_offset[0] ^= KECCAK_ROUND_CONSTANTS[round];
    (i64.store (get_local $context_offset)
      (i64.xor
        (i64.load (get_local $context_offset))
        (i64.load (i32.add (get_local $round_consts) (i32.mul (i32.const 8) (get_local $round))))
      )
    )

    (set_local $round (i32.add (get_local $round) (i32.const 1)))
    (br $loop)
  )  
)

(func $KECCAK_BLOCK
  (param $input_offset i32)
  (param $input_length i32) ;; ignored, we expect keccak256
  (param $context_offset i32)

  ;; read blocks in little-endian order and XOR against context_offset

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 0))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 0)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 0)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 8))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 8)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 8)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 16))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 16)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 16)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 24))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 24)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 24)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 32))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 32)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 32)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 40))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 40)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 40)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 48))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 48)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 48)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 56))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 56)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 56)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 64))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 64)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 64)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 72))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 72)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 72)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 80))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 80)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 80)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 88))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 88)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 88)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 96))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 96)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 96)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 104))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 104)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 104)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 112))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 112)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 112)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 120))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 120)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 120)))
    )
  )

  (i64.store
    (i32.add (get_local $context_offset) (i32.const 128))
    (i64.xor
      (i64.load (i32.add (get_local $context_offset) (i32.const 128)))
      (i64.load (i32.add (get_local $input_offset) (i32.const 128)))
    )
  )
  
  (call $KECCAK_PERMUTE (get_local $context_offset))
)

;;
;; Initialise the context
;;
(func $KECCAK_INIT
  (param $context_offset i32)
  (local $round_consts i32)
  (local $rotation_consts i32)

  (call $KECCAK_RESET (get_local $context_offset))

  ;; insert the round constants (used by $KECCAK_IOTA)
  (set_local $round_consts (i32.add (get_local $context_offset) (i32.const 400)))
  (i64.store (i32.add (get_local $round_consts) (i32.const 0)) (i64.const 0x0000000000000001))
  (i64.store (i32.add (get_local $round_consts) (i32.const 8)) (i64.const 0x0000000000008082))
  (i64.store (i32.add (get_local $round_consts) (i32.const 16)) (i64.const 0x800000000000808A))
  (i64.store (i32.add (get_local $round_consts) (i32.const 24)) (i64.const 0x8000000080008000))
  (i64.store (i32.add (get_local $round_consts) (i32.const 32)) (i64.const 0x000000000000808B))
  (i64.store (i32.add (get_local $round_consts) (i32.const 40)) (i64.const 0x0000000080000001))
  (i64.store (i32.add (get_local $round_consts) (i32.const 48)) (i64.const 0x8000000080008081))
  (i64.store (i32.add (get_local $round_consts) (i32.const 56)) (i64.const 0x8000000000008009))
  (i64.store (i32.add (get_local $round_consts) (i32.const 64)) (i64.const 0x000000000000008A))
  (i64.store (i32.add (get_local $round_consts) (i32.const 72)) (i64.const 0x0000000000000088))
  (i64.store (i32.add (get_local $round_consts) (i32.const 80)) (i64.const 0x0000000080008009))
  (i64.store (i32.add (get_local $round_consts) (i32.const 88)) (i64.const 0x000000008000000A))
  (i64.store (i32.add (get_local $round_consts) (i32.const 96)) (i64.const 0x000000008000808B))
  (i64.store (i32.add (get_local $round_consts) (i32.const 104)) (i64.const 0x800000000000008B))
  (i64.store (i32.add (get_local $round_consts) (i32.const 112)) (i64.const 0x8000000000008089))
  (i64.store (i32.add (get_local $round_consts) (i32.const 120)) (i64.const 0x8000000000008003))
  (i64.store (i32.add (get_local $round_consts) (i32.const 128)) (i64.const 0x8000000000008002))
  (i64.store (i32.add (get_local $round_consts) (i32.const 136)) (i64.const 0x8000000000000080))
  (i64.store (i32.add (get_local $round_consts) (i32.const 144)) (i64.const 0x000000000000800A))
  (i64.store (i32.add (get_local $round_consts) (i32.const 152)) (i64.const 0x800000008000000A))
  (i64.store (i32.add (get_local $round_consts) (i32.const 160)) (i64.const 0x8000000080008081))
  (i64.store (i32.add (get_local $round_consts) (i32.const 168)) (i64.const 0x8000000000008080))
  (i64.store (i32.add (get_local $round_consts) (i32.const 176)) (i64.const 0x0000000080000001))
  (i64.store (i32.add (get_local $round_consts) (i32.const 184)) (i64.const 0x8000000080008008))

  ;; insert the rotation constants (used by $KECCAK_RHO)
  (set_local $rotation_consts (i32.add (get_local $context_offset) (i32.const 592)))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 0)) (i64.const 1))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 8)) (i64.const 62))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 16)) (i64.const 28))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 24)) (i64.const 27))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 32)) (i64.const 36))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 40)) (i64.const 44))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 48)) (i64.const 6))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 56)) (i64.const 55))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 64)) (i64.const 20))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 72)) (i64.const 3))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 80)) (i64.const 10))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 88)) (i64.const 43))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 96)) (i64.const 25))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 104)) (i64.const 39))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 112)) (i64.const 41))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 120)) (i64.const 45))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 128)) (i64.const 15))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 136)) (i64.const 21))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 144)) (i64.const 8))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 152)) (i64.const 18))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 160)) (i64.const 2))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 168)) (i64.const 61))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 176)) (i64.const 56))
  (i64.store (i32.add (get_local $rotation_consts) (i32.const 184)) (i64.const 14))
)

;;
;; Reset the context
;;
(func $KECCAK_RESET
  (param $context_offset i32)

  ;; clear out the context memory
  (call $memset (get_local $context_offset) (i32.const 0) (i32.const 400))
)

;;
;; Push input to the context
;;
(func $KECCAK_UPDATE
  (param $context_offset i32)
  (param $input_offset i32)
  (param $input_length i32)

  (local $residue_offset i32)
  (local $residue_buffer i32)
  (local $residue_index i32)
  (local $tmp i32)

  ;; this is where we store the pointer
  (set_local $residue_offset (i32.add (get_local $context_offset) (i32.const 200)))
  ;; this is where the buffer is
  (set_local $residue_buffer (i32.add (get_local $context_offset) (i32.const 208)))

  (set_local $residue_index (i32.load (get_local $residue_offset)))

  ;; process residue from last block
  (if (i32.ne (get_local $residue_index) (i32.const 0))
    (then
      ;; the space left in the residue buffer
      (set_local $tmp (i32.sub (i32.const 136) (get_local $residue_index)))

      ;; limit to what we have as an input
      (if (i32.lt_u (get_local $input_length) (get_local $tmp))
        (set_local $tmp (get_local $input_length))
      )

      ;; fill up the residue buffer
      (call $memcpy
        (i32.add (get_local $residue_buffer) (get_local $residue_index))
        (get_local $input_offset)
        (get_local $tmp)
      )

      (set_local $residue_index (i32.add (get_local $residue_index) (get_local $tmp)))

      ;; block complete
      (if (i32.eq (get_local $residue_index) (i32.const 136))
        (call $KECCAK_BLOCK (get_local $input_offset) (i32.const 136) (get_local $context_offset))

        (set_local $residue_index (i32.const 0))
      )

      (i32.store (get_local $residue_offset) (get_local $residue_index))

      (set_local $input_length (i32.sub (get_local $input_length) (get_local $tmp)))
    )
  )

  ;; while (input_length > block_size)
  (loop $done $loop
    (if (i32.lt_u (get_local $input_length) (i32.const 136))
      (br $done)
    )

    (call $KECCAK_BLOCK (get_local $input_offset) (i32.const 136) (get_local $context_offset))

    (set_local $input_offset (i32.add (get_local $input_offset) (i32.const 136)))
    (set_local $input_length (i32.sub (get_local $input_length) (i32.const 136)))
    (br $loop)
  )

  ;; copy to the residue buffer
  (if (i32.gt_u (get_local $input_length) (i32.const 0))
    (then
      (call $memcpy
        (i32.add (get_local $residue_buffer) (get_local $residue_index))
        (get_local $input_offset)
        (get_local $input_length)
      )

      (set_local $residue_index (i32.add (get_local $residue_index) (get_local $input_length)))
      (i32.store (get_local $residue_offset) (get_local $residue_index))
    )
  )
)

;;
;; Finalise and return the hash
;;
;; The 256 bit hash is returned at the output offset.
;;
(func $KECCAK_FINISH
  (param $context_offset i32)
  (param $output_offset i32)

  (local $residue_offset i32)
  (local $residue_buffer i32)
  (local $residue_index i32)
  (local $tmp i32)

  ;; this is where we store the pointer
  (set_local $residue_offset (i32.add (get_local $context_offset) (i32.const 200)))
  ;; this is where the buffer is
  (set_local $residue_buffer (i32.add (get_local $context_offset) (i32.const 208)))

  (set_local $residue_index (i32.load (get_local $residue_offset)))
  (set_local $tmp (get_local $residue_index))

  ;; clear the rest of the residue buffer
  (call $memset (i32.add (get_local $residue_buffer) (get_local $tmp)) (i32.const 0) (i32.sub (i32.const 136) (get_local $tmp)))

  ;; ((char*)ctx->message)[ctx->rest] |= 0x01;
  (set_local $tmp (i32.add (get_local $residue_buffer) (get_local $residue_index)))
  (i32.store8 (get_local $tmp) (i32.or (i32.load8_u (get_local $tmp)) (i32.const 0x01)))

  ;; ((char*)ctx->message)[block_size - 1] |= 0x80;
  (set_local $tmp (i32.add (get_local $residue_buffer) (i32.const 135)))
  (i32.store8 (get_local $tmp) (i32.or (i32.load8_u (get_local $tmp)) (i32.const 0x80)))

  (call $KECCAK_BLOCK (get_local $residue_buffer) (i32.const 136) (get_local $context_offset))

  ;; the first 32 bytes pointed at by $output_offset is the final hash
  (i64.store (get_local $output_offset) (i64.load (get_local $context_offset)))
  (i64.store (i32.add (get_local $output_offset) (i32.const 8)) (i64.load (i32.add (get_local $context_offset) (i32.const 8))))
  (i64.store (i32.add (get_local $output_offset) (i32.const 16)) (i64.load (i32.add (get_local $context_offset) (i32.const 16))))
  (i64.store (i32.add (get_local $output_offset) (i32.const 24)) (i64.load (i32.add (get_local $context_offset) (i32.const 24))))
)

;;
;; Calculate the hash. Helper method incorporating the above three.
;;
(func $KECCAK
  (param $context_offset i32)
  (param $input_offset i32)
  (param $input_length i32)
  (param $output_offset i32)

  (call $KECCAK_INIT (get_local $context_offset))
  (call $KECCAK_UPDATE (get_local $context_offset) (get_local $input_offset) (get_local $input_length))
  (call $KECCAK_FINISH (get_local $context_offset) (get_local $output_offset))
)
