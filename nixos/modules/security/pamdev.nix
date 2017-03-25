{ config, lib, pkgs, ... }:

let
  parentConfig = config;
  controlActionSet = types.mkOptionType {
    name = controlActionsSet;
    description = "Attribute set of PAM control actions";
    # A control action set is an attribute set where all the keys are
    # from the first list and all values are from the second list or
    # integers greater than zero.
    check = set: (isAttrs set) && (filterAttrs
     (n: v: (any (name: n == name)
        [ "success" "open_err" "symbol_err" "service_err" "system_err"
          "buf_err" "perm_denied" "auth_err" "cred_insufficient"
          "authinfo_unavail" "user_unknown" "maxtries"
          "new_authtok_reqd" "acct_expired" "session_err"
          "cred_unavail" "cred_expired" "cred_err" "no_module_data"
          "conv_err" "authtok_err" "authtok_recover_err"
          "authtok_lock_busy" "authtok_disable_aging" "try_again"
          "ignore" "abort" "authtok_expired" "module_unknown"
          "bad_item" "conv_again" "incomplete" "default" ])
      && ((any (value: v == value) [ "ignore" "bad" "die" "ok" "done" "reset"])
          || (v > 1)))
      set
      == {});
  };
  mgmtGroup = {config, name, ... }:  let cfg = config; in let config = parentConfig; in {
    options = {
      control = mkOption {
        example = "{ success = ok; new_auth_tok_reqd = ok; ignore = ignore; default = die; }";
        type = controlActionSet;
        description = "Control value that defines success and failure of this PAM provider";
        default = { default = ignore; };
      };
      module = mkOption {
        example = "${pkgs.systemd}/lib/security/pam_systemd.so";
        type = types.str;
        description = "Path to the PAM module";
      };
      args = mkOption {
        example = "nullok";
        type = with types; either str (listOf str);
        default = "";
        description = "List of arguments to the PAM module";
      };
    };
  };
  provider = {
    name = mkOption {
      example = "krb5";
      type = types.str;
      description = "Name of the PAM service.";
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

  cfg = config.security.pamdev;
  zipListsLongWith = f: nul: fst: snd:
    genList
      (n: f (elemAt fst n) (if (n < (length snd)) (elemAt snd n) nul)) (length fst);

  makePAMService = pamService:
    let
      lines = pamservice: lib.mapAttrs
                (grp-name: val: map
		  (acc: "${grp-name} ${acc.c} ${acc.m}${lib.optionalString (acc ? a) " ${acc.a}"}") val)
		(lib.filterAttrs (n: v: n == "account"
                                     || n == "auth"
                                     || n == "session"
                                     || n == "password") pamservice);

      # lines = map (grp: (map (acc: "account ${acc.control} ${acc.module} ")
      #                        grp))
      #             with pamService; [ account auth password session ];
    in
    { source = pkgs.writeText "${pamService.name}.pam" lines;
      target = "pam.d/${pamService.name}";
    };

in
{
  options = {
    security.pamdev.providers = mkOption {
      default = [];
      description = "List of PAM service providers";
      type = with types; loaOf (submodule pamOpts);
    };
  };

  config = {
    #evironment.etc = mapAttrsToList (n: v: makePAMService v) cfg.services;

    security.pamdev.providers = {
      unix = rec {
        account = lib.singleton {
          module = "pam_unix.so"
          control = { success = done; new_auth_reqd = done; default = ignore; }; # sufficient
        };
        auth = map (v: // { args = [ "nullok" "likeauth" "try_first_pass" ]; }) account;
        session = account;
      };
    };
  };
}
