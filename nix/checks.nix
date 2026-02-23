{
  pkgs,
  src,
  goModules,
}: {
  # Run tests
  go-tests = pkgs.stdenv.mkDerivation {
    name = "opnix-go-tests";
    inherit src;

    nativeBuildInputs = [pkgs.go];

    buildPhase = ''
      export GOPATH=$TMPDIR/go
      export GOCACHE=$TMPDIR/go-cache
      export GOFLAGS="-mod=vendor"

      # Link vendored dependencies from the buildGoModule FOD
      ln -s ${goModules} vendor

      go test ./...
    '';

    installPhase = "touch $out";
  };

  # Run golangci-lint
  go-lint = pkgs.stdenv.mkDerivation {
    name = "opnix-go-lint";
    inherit src;

    nativeBuildInputs = [pkgs.go pkgs.golangci-lint];

    buildPhase = ''
      export GOPATH=$TMPDIR/go
      export GOCACHE=$TMPDIR/go-cache
      export GOFLAGS="-mod=vendor"
      export GOLANGCI_LINT_CACHE=$TMPDIR/golangci-lint
      export XDG_CACHE_HOME=$TMPDIR/cache

      mkdir -p $GOLANGCI_LINT_CACHE $XDG_CACHE_HOME $GOCACHE $GOPATH

      # Link vendored dependencies from the buildGoModule FOD
      ln -s ${goModules} vendor

      ${
        let
          cfg = ''
            version: "2"
            linters:
              default: standard
              settings:
                errcheck:
                  exclude-functions:
                    - fmt.Fprintf
              exclusions:
                rules:
                  - path: ".*_test\\.go$"
                    linters:
                      - errcheck
          '';
        in "echo -n '${cfg}' >> .golangci.yaml"
      }

      golangci-lint run --allow-parallel-runners \
        --timeout=5m \
        --max-same-issues=20 \
        ./...
    '';

    installPhase = "touch $out";
  };

  # Check nix formatting
  nix-fmt-check =
    pkgs.runCommand "opnix-nix-fmt-check"
    {
      nativeBuildInputs = [pkgs.alejandra];
      inherit src;
    } ''
      cp -r $src/* .
      alejandra --check .
      touch $out
    '';
}
