{
  description = "Development inputs for github-actions-nix. These are used by the top level flake in the dev partition, but do not appear in consumers' lock files.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    hk = {
      url = "git+https://github.com/jdx/hk?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  # This flake is only used for its inputs
  outputs = _: {};
}
