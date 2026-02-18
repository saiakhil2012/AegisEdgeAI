package localauthority

// This file provides WIT authority stub implementations required to satisfy the
// localauthorityv1.LocalAuthorityServer interface added in SPIRE v1.14.1.  The
// real implementation is out of scope for AegisSovereignAI; these stubs return
// Unimplemented so that the server compiles and all other LocalAuthority RPCs work.

import (
	"context"

	localauthorityv1 "github.com/spiffe/spire-api-sdk/proto/spire/api/server/localauthority/v1"
	"github.com/spiffe/spire/pkg/server/api"
	"github.com/spiffe/spire/pkg/server/api/rpccontext"
	"google.golang.org/grpc/codes"
)

// GetWITAuthorityState implements localauthorityv1.LocalAuthorityServer.
func (s *Service) GetWITAuthorityState(ctx context.Context, _ *localauthorityv1.GetWITAuthorityStateRequest) (*localauthorityv1.GetWITAuthorityStateResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}

// PrepareWITAuthority implements localauthorityv1.LocalAuthorityServer.
func (s *Service) PrepareWITAuthority(ctx context.Context, _ *localauthorityv1.PrepareWITAuthorityRequest) (*localauthorityv1.PrepareWITAuthorityResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}

// ActivateWITAuthority implements localauthorityv1.LocalAuthorityServer.
func (s *Service) ActivateWITAuthority(ctx context.Context, req *localauthorityv1.ActivateWITAuthorityRequest) (*localauthorityv1.ActivateWITAuthorityResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}

// TaintWITAuthority implements localauthorityv1.LocalAuthorityServer.
func (s *Service) TaintWITAuthority(ctx context.Context, req *localauthorityv1.TaintWITAuthorityRequest) (*localauthorityv1.TaintWITAuthorityResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}

// RevokeWITAuthority implements localauthorityv1.LocalAuthorityServer.
func (s *Service) RevokeWITAuthority(ctx context.Context, req *localauthorityv1.RevokeWITAuthorityRequest) (*localauthorityv1.RevokeWITAuthorityResponse, error) {
	log := rpccontext.Logger(ctx)
	return nil, api.MakeErr(log, codes.Unimplemented, "WIT-SVID functionality is not yet implemented", nil)
}
