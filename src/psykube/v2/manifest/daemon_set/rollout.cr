class Psykube::V2::Manifest::DaemonSet::Rollout
  Macros.mapping({
    history_limit:   {type: Int32, nilable: true},
    max_unavailable: {type: Int32 | String, default: "25%"},
  })
end
