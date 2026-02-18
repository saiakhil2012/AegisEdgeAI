package util

// MustCast performs a type assertion from any to T, panicking if the value
// cannot be converted. This is equivalent to v.(T) but works in contexts where
// the type parameter T is needed explicitly (e.g., integer code conversions).
//
// Usage:
//
//	code := util.MustCast[codes.Code](s.Code)
func MustCast[T any](v any) T {
	return v.(T)
}
