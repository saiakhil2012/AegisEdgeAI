package svid

// This file provides WIT-SVID stub implementations required to satisfy the
// svidv1.SVIDServer interface added in SPIRE v1.14.1.  The real implementation
// is out of scope for AegisSovereignAI; these stubs return Unimplemented so
// that the server compiles and all other SVID RPCs continue to work.

import (
	"context"

	svidv1 "github.com/spiffe/spire-api-sdk/proto/spire/api/server/svid/v1"
	"github.com/spiffe/spire/pkg/server/api"
	"github.com/spiffe/spire/pkg/server/api/rpccontext"
	"google.golang.org/grpc/codes"
)

// MintWITSVID implements svidv1.SVIDServer.
// WIT-SVID functionality is not yet implemented.
func (s *Service) MintWITSVID(ctx context.Context, req *svidv1.MintWITSVIDRequest) (*svidv1.MintWITSVIDResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}

// BatchNewWITSVID implements svidv1.SVIDServer.
// WIT-SVID functionality is not yet implemented.
func (s *Service) BatchNewWITSVID(ctx context.Context, req *svidv1.BatchNewWITSVIDRequest) (*svidv1.BatchNewWITSVIDResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}
