{ config, lib, pkgs, ... }:

let
  inherit (lib) all any attrValues flatten mapAttrsToList mkDefault mkOption mkOptionType types
                genList elemAt filterAttrs length mapAttrs optionalString stringToCharacters escape optional;
  inherit (builtins) isAttrs isInt concatStringsSep filter;
  inherit (lib.pamfuns) mkPAM mkPAMA;
  parentConfig = config;

  # A control action set is an attribute set where all the keys are
  # from the first list and all values are from the second list or
  # integers greater than zero.
  controlActionCheck = set: (isAttrs set) && (filterAttrs
      (n: v: !((any (name: n == name)
                    [ "success" "open_err" "symbol_err" "service_err" "system_err"
                      "buf_err" "perm_denied" "auth_err" "cred_insufficient"
                      "authinfo_unavail" "user_unknown" "maxtries"
                      "new_authtok_reqd" "acct_expired" "session_err"
                      "cred_unavail" "cred_expired" "cred_err" "no_module_data"
                      "conv_err" "authtok_err" "authtok_recover_err"
                      "authtok_lock_busy" "authtok_disable_aging" "try_again"
                      "ignore" "abort" "authtok_expired" "module_unknown"
                      "bad_item" "conv_again" "incomplete" "default" ])
              && ((any (value: v == value)
                       [ "ignore" "bad" "die" "ok" "done" "reset" ])
                  || ((isInt v) && (v > 0)))))
      set
    == {});

  controlActionSet = mkOptionType {
    name = controlActionSet;
    description = "Attribute set of PAM control actions";
    check = controlActionCheck;
  };

  mgmtGroup = {config, name, ... }:  let cfg = config; in let config = parentConfig; in {
    options = {
      control = mkOption {
        example = { success = "ok"; new_auth_tok_reqd = "ok"; ignore = "ignore"; default = "die"; };
        type = controlActionSet;
        description = "Control value that defines success and failure of this PAM provider";
        default = { default = "ignore"; };
      };
      module = mkOption {
        example = "${pkgs.systemd}/lib/security/pam_systemd.so";
        type = types.str;
        description = "Path to the PAM module";
      };
      args = mkOption {
        example = [ "nullok" ];
        type = with types; listOf str;
        default = [];
        description = "List of arguments to the PAM module";
      };
    };
  };

  provider = { config, name, ... }: let cfg = config; in let config = parentConfig; in {
    options = {
      name = mkOption {
        example = "krb5";
        type = with types; nullOr str;
        description = ''
          Name of the PAM provider if it denotes a PAM service. Set to
          <literal>null</literal> if this provider is just a partial
          set of management groups to be used by other PAM service,
          like `system-auth` or `common-auth' are on other
          distributions.
        '';
      };

      account = mkOption {
        default = [];
        type = with types; listOf (submodule mgmtGroup);
        description = "The account management group";
      };

      auth = mkOption {
        default = [];
        type = with types; listOf (submodule mgmtGroup);
        description = "The auth management group";
      };

      password = mkOption {
        default = [];
        type = with types; listOf (submodule mgmtGroup);
        description = "The password management group";
      };

      session = mkOption {
        default = [];
        type = with types; listOf (submodule mgmtGroup);
        description = "The session management group";
      };
    };

    config = {
      name = mkDefault name;
    };
  };

  cfg = config.security.pamdev;

  makePAMService = pamService: if pamService.name != null then
    let
      getMgmtGroups = filterAttrs (n: v: any (p: n == p) [ "account" "auth" "session" "password" ]);
      hasWhitespace = s: any (c: any (w: w == c) [ " " "\n" "\t" ]) (stringToCharacters s);
      quoteArg = arg: if (hasWhitespace arg) then "[" + (escape [ "]" "\n" ] arg) + "]" else arg;
      printControl = ctrl: concatStringsSep " " (mapAttrsToList (n: v: n + "=" + v) ctrl);
      printLine = group-name: content:
        map (mod: group-name + " [" + (printControl mod.control) + "] " + mod.module
                  + optionalString (mod.args != [])
                     " " + (concatStringsSep " " (map quoteArg mod.args))) content;
      lines = pamservice: concatStringsSep "\n" (flatten (mapAttrsToList printLine (getMgmtGroups pamservice)));
    in
    { source = pkgs.writeText "${pamService.name}.pam" (lines pamService);
      target = "pamdev.d/${pamService.name}";
    }
  else null;

in
{
  options = {
    security.pamdev = {

      rootOK = mkOption {
        type = types.bool;
	default = true;
      };

      requireWheel = mkOption {
        type = types.bool;
	default = true;
      };

      providers = mkOption {
        default = [];
        description = "List of PAM service providers";
        type = with types; attrsOf (submodule provider);
      };

      controls = mkOption {
        default = {
          optional = { success = "ok"; new_authtok_reqd = "ok"; default = "ignore"; };
          required = { success = "ok"; new_authtok_reqd = "ok"; ignore = "ignore"; default = "bad"; };
          requisite = { success = "ok"; new_authtok_reqd = "ok"; ignore = "ignore"; default = "die"; };
          sufficient = { success = "done"; new_authtok_reqd = "done"; default = "ignore"; };
        };
        type = with types; addCheck attrs (set: all controlActionCheck (attrValues set));
        description = "Shortcut values for PAM control actions like 'sufficient' or 'required'";
      };
      text = mkOption {
        type = types.unspecified;
      };
    };
  };

  config = {
    environment.etc = filter (e: e != null) (mapAttrsToList (n: v: makePAMService v) cfg.providers);

    security.pamdev = with cfg.controls; {
      providers = {
        other = rec {
	  account = [
	  { module = "pam_warn.so";
	    control = required;
	  } {
	    module = "pam_deny.so";
	    control = required;
	  } ];
	  auth = account;
	  password = account; 
	  session = account;
	};
	common-service = {
  	  name = null;
	  account = [ (mkPAM "pam_unix.so" required) ];
	  auth = (optional cfg.rootOK (mkPAM "pam_rootok.so" sufficient)) ++
                 (optional cfg.requireWheel (mkPAMA "pam_wheels.o" sufficient [ "use_uid" ]));
	};

        unix = rec {
	  name = null;
          account = [
          { module = "pam_unix.so";
            control = cfg.controls.sufficient;
          } ];
          #auth = map (v: v // { args = [ "nullok" ''likeauth=has ]whitespace foo'' "try_first_pass" ]; }) account;
          #password = account;
          #session = account;
        };
      };
      text = makePAMService;
    };
  };
}
