{
  description = "Dev environment";

  inputs = {
    # 使用清华 nixpkgs.git 镜像（这是真正的 Git 仓库）
    nixpkgs.url = "git+https://mirrors.tuna.tsinghua.edu.cn/git/nixpkgs.git?ref=nixos-24.11" ;
  };

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          git curl hello
        ];
      };
    };
}
