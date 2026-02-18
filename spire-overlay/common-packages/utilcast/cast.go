package util

import "fmt"

// Int is a type constraint for all integer types, used by CheckedCast and MustCast.
type Int interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 | ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64
}

// CheckedCast converts a value from one integer type to another, returning an
// error if the conversion would overflow or change the sign.
func CheckedCast[To, From Int](v From) (To, error) {
	result := To(v)
	if (v < 0) != (result < 0) || From(result) != v {
		return 0, fmt.Errorf("overflow converting %T(%v) to %T", v, v, result)
	}
	return result, nil
}

// MustCast converts a value from one integer type to another, panicking if the
// conversion would overflow or change the sign.
func MustCast[To, From Int](v From) To {
	x, err := CheckedCast[To](v)
	if err != nil {
		panic(err)
	}
	return x
}
