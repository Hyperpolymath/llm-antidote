{
  description = "llm-antidote - Universal semantic reset artifacts for language model context management";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        # Python with required dependencies
        python = pkgs.python3.withPackages (ps: with ps; [
          # No external dependencies required - pure Python
        ]);

        # Development tools
        devTools = with pkgs; [
          python
          just
          git
          tree
        ];

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          buildInputs = devTools;

          shellHook = ''
            echo "🧬 llm-antidote development environment"
            echo "======================================"
            echo ""
            echo "Python: $(python --version)"
            echo "Just: $(just --version)"
            echo ""
            echo "Available commands:"
            echo "  just help     - Show all available commands"
            echo "  just test     - Run test suite"
            echo "  just validate - Validate all files"
            echo "  just rsr-check - Check RSR compliance"
            echo ""
            echo "Version: $(cat VERSION)"
            echo ""
          '';
        };

        # Package the project
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "llm-antidote";
          version = builtins.readFile ./VERSION;

          src = ./.;

          buildInputs = [ python ];

          installPhase = ''
            mkdir -p $out/{bin,share/llm-antidote}

            # Copy artifacts
            cp -r artifacts $out/share/llm-antidote/
            cp -r tools $out/share/llm-antidote/
            cp -r examples $out/share/llm-antidote/
            cp -r docs $out/share/llm-antidote/
            cp -r tests $out/share/llm-antidote/

            # Copy documentation
            cp README.md LICENSE CONTRIBUTING.md SECURITY.md $out/share/llm-antidote/
            cp CODE_OF_CONDUCT.md MAINTAINERS.md CHANGELOG.md $out/share/llm-antidote/

            # Copy .well-known
            cp -r .well-known $out/share/llm-antidote/

            # Install CLI tool
            cat > $out/bin/llm-antidote <<EOF
            #!/bin/sh
            exec ${python}/bin/python $out/share/llm-antidote/tools/llm-cli.py "\$@"
            EOF
            chmod +x $out/bin/llm-antidote

            # Install diagnostic tool
            cat > $out/bin/llm-diagnostic <<EOF
            #!/bin/sh
            exec ${python}/bin/python $out/share/llm-antidote/tools/llm-diagnostic.py "\$@"
            EOF
            chmod +x $out/bin/llm-diagnostic

            # Install benchmark tool
            cat > $out/bin/llm-benchmark <<EOF
            #!/bin/sh
            exec ${python}/bin/python $out/share/llm-antidote/tools/benchmark.py "\$@"
            EOF
            chmod +x $out/bin/llm-benchmark
          '';

          meta = with pkgs.lib; {
            description = "Universal semantic reset artifacts for language model context management";
            homepage = "https://github.com/Hyperpolymath/llm-antidote";
            license = licenses.cc0;
            platforms = platforms.all;
            maintainers = [ ];
          };
        };

        # Apps for easy execution
        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/llm-antidote";
          };

          diagnostic = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/llm-diagnostic";
          };

          benchmark = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/llm-benchmark";
          };
        };

        # Checks for CI
        checks = {
          validate-python = pkgs.runCommand "validate-python" {
            buildInputs = [ python ];
          } ''
            cd ${self}
            ${python}/bin/python -m py_compile tools/*.py tests/*.py
            touch $out
          '';

          rsr-compliance = pkgs.runCommand "rsr-compliance" {
            buildInputs = [ python ];
          } ''
            cd ${self}
            ${python}/bin/python tools/rsr-compliance.py
            touch $out
          '';
        };
      }
    );
}
