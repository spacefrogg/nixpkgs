with {
  inherit (import ./attrsets.nix) foldAttrs filterAttrs;
  inherit (import ./lists.nix) any;
};

rec {

  /* Return the attribute set containing only the management groups of a PAM provider.
  */
  getMgmtGroups = filterAttrs (n: v: any (e: e == n) [ "account" "auth" "password" "session" ]);

  /* Return an attribute set containing PAM management groups
     from a list of PAM providers.

     Example:
      unix = { account = [ { module = "pam_unix.so"; control = sufficient; } ]; 
               _module = { ... }; }
      permit = { account = [ { module = "pam_permit.so"; control = optional; } ];
                 session = [ { module = "pam_permit.so"; control = sufficient; } ];
                 _module = { ... }; }
      mergePAMProviders [ unix permit ]
      => { account = [ { module = "pam_unix.so"; control = sufficient; }
                       { module = "pam_permit.so"; control = optional; } ];
           session = [ { module = "pam_permit.so"; control = sufficient; } ]; }

     Beware that the result is not a PAM provider, which has to be a submodule, but
     can be assigned to an attribute below security.pam.providers to make one.

     Complex example:
     unix = ...
     permit = ...

     security.pam.providers.fancy = {
       inherit (mergePAMProviders [ unix permit ]) account
     } // {
       session = map (e: e.control = required; ) permit.session;
     }
     =>
     { account = [ ... ];
       session = [ { module = "pam_permit.so"; control = required; } ]; }
  */
  mergePAMProviders = pvs: foldAttrs (n: a: n ++ a) [] (map getMgmtGroups pvs);
}
