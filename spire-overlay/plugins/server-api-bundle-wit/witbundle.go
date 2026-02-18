package bundle

// This file provides WIT authority stub implementations required to satisfy the
// bundlev1.BundleServer interface added in SPIRE v1.14.1.  The real
// implementation is out of scope for AegisSovereignAI; this stub returns
// Unimplemented so that the server compiles and all other Bundle RPCs work.

import (
	"context"

	bundlev1 "github.com/spiffe/spire-api-sdk/proto/spire/api/server/bundle/v1"
	"github.com/spiffe/spire/pkg/server/api"
	"github.com/spiffe/spire/pkg/server/api/rpccontext"
	"google.golang.org/grpc/codes"
)

// PublishWITAuthority implements bundlev1.BundleServer.
// WIT authority publishing is not yet implemented.
func (s *Service) PublishWITAuthority(ctx context.Context, req *bundlev1.PublishWITAuthorityRequest) (*bundlev1.PublishWITAuthorityResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}
