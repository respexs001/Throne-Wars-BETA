extends RefCounted
## PBKDF2-HMAC-SHA256, 32-byte output. Work runs off the UI thread.
const ITERATIONS: int = 600000
const OFFSETS: Array[int] = [0, 8, 16, 24]
static func derive(password: String, salt: PackedByteArray, iterations: int = ITERATIONS) -> PackedByteArray:
    var crypto := Crypto.new()
    var key := password.to_utf8_buffer()
    var first: PackedByteArray = salt + PackedByteArray([0, 0, 0, 1])
    var u := crypto.hmac_digest(HashingContext.HASH_SHA256, key, first)
    var result := u.duplicate()
    for i in range(1, iterations):
        u = crypto.hmac_digest(HashingContext.HASH_SHA256, key, u)
        for offset in OFFSETS:
            result.encode_u64(offset, result.decode_u64(offset) ^ u.decode_u64(offset))
    key.fill(0)
    return result
