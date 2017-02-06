{ config, pkgs, lib, ... }:

with lib;
let
  cfg = config.services.openafsServer;
  openafsPkgs = config.services.openafsServer.openafsPkgs;
  netInfo = if (cfg.advertisedAddresses != []) then
    pkgs.writeText "NetInfo" ((concatStringsSep ''

      f '' cfg.advertisedAddresses) + ''

      '')
    else null;
  afsConfig = pkgs.runCommand "afsconfig" { } ''
    mkdir -p $out/server
    echo ${cfg.cellName} > $out/server/ThisCell
    cp ${cellServDB} $out/server/CellServDB
    cp ${cfg.bosConfig} $out/BosConfig
    printf "${concatStringsSep "\n" cfg.adminUsers }" >$out/server/UserList
    chmod 600 $out/server/UserList
  '';
  cellServDB = pkgs.writeText "CellServDB" ''
    >${cfg.cellName}
    ${concatStringsSep "\n" (map ({ address, hostname }: concatStringsSep " \#" [ address hostname ]) cfg.cellServers)}    
  '';
  bosConfig = pkgs.writeText "BosConfig" ''
    restarttime 16 0 0 0 0
    checkbintime 3 0 5 0 0
    bnode simple vlserver 1
    parm ${openafsPkgs}/libexec/openafs/vlserver
    end
    bnode simple ptserver 1
    parm ${openafsPkgs}/libexec/openafs/ptserver -db /var/openafs/prdb -restricted
    end
    bnode dafs dafs 1
    parm ${openafsPkgs}/libexec/openafs/dafileserver -vattachpar 128 -vhashsize 11 -cb 1000000
    parm ${openafsPkgs}/libexec/openafs/davolserver
    parm ${openafsPkgs}/libexec/openafs/salvageserver
    parm ${openafsPkgs}/libexec/openafs/dasalvager
    end
  '';
in
{
  options = {

    services.openafsServer = {

      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable the OpenAFS server.";
      };

      adminUsers = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "List of OpenAFS users that can administer this server.";
      };

      advertisedAddresses = mkOption {
        default = [];
        type = types.listOf types.str;
        description = "List of IP addresses this server is advertised under. See NetInfo(5)";
      };
      bosConfig = mkOption {
        type = types.package;
        default = bosConfig;
        defaultText = ''
          restarttime 16 0 0 0 0
          checkbintime 3 0 5 0 0
          bnode simple vlserver 1
          parm ''${cfg.openafsPkgs}/libexec/openafs/vlserver
          end
          bnode simple ptserver 1
          parm ''${cfg.openafsPkgs}/libexec/openafs/ptserver -db /var/openafs/prdb -restricted
          end
          bnode dafs dafs 1
          parm ''${cfg.openafsPkgs}/libexec/openafs/dafileserver -vattachpar 128 -vhashsize 11 -cb 1000000
          parm ''${cfg.openafsPkgs}/libexec/openafs/davolserver
          parm ''${cfg.openafsPkgs}/libexec/openafs/salvageserver
          parm ''${cfg.openafsPkgs}/libexec/openafs/dasalvager
          end
        '';
        description = "The server configuration file specifying the started servers and options";
      };

      cellName = mkOption {
        type = types.str;
        default = "grand.central.org";
        description = "Server's cell name.";
      };

      cellServers = mkOption {
        type = types.listOf (mkOptionType {
          name = "IPNameMap";
          description = "map of IP address to DNS name";
          check = x: isAttrs x && x ? address && x ? hostname;
          merge = mergeOneOption;
        });

        default = [];
        description = "IP addresses of database servers that serve this cell.";
        example = literalExample ''
          [ { address = "10.0.0.3"; hostname = "afsdb.example.org"; } ]
        '';
      };

      openafsPkgs = mkOption {
        type = types.package;
        default = config.boot.kernelPackages.openafs;
        defaultText = "config.boot.kernelPackages.openafs";
        description = "The package to use for the openafs servers";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ openafsPkgs ];

    systemd.services = {
      openafs-server = {
        description = "OpenAFS server";
        after = [ "syslog.target" "network.target" ];
        preStart = ''
          mkdir -p /etc/openafs/server
          cp -r ${afsConfig}/* /etc/openafs #*/
          mkdir -p /var/openafs
          rm -f /var/openafs/NetInfo
          cp "${netInfo}" /var/openafs/NetInfo
        '';
        wantedBy = [ "multi-user.target" ];
        unitConfig = {
          ConditionFileNotEmpty = [ "|/etc/openafs/server/rxkad.keytab"
                                    "|/etc/openafs/server/KeyFile" ];
        };
        serviceConfig = {
          ExecStart = "${openafsPkgs}/bin/bosserver -nofork";
          ExecStop = "${openafsPkgs}/bin/bos shutdown localhost -wait -localauth";
        };
      };
    };
  };
}
