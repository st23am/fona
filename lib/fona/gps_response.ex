defmodule Fona.GpsResponse do
  @response_fields [
    run_status: "0",
    fix_status: "0",
    datetime: "",
    latitude: "0.0",
    longitude: "0.0",
    altitude: "0.0",
    speed: "0.0",
    course: "0.0",
    fix_mode: "0",
    reserved1: "",
    hdop: "0.0",
    pdop: "0.0",
    vdop: "1.0",
    reserved2: "",
    gnss_sats_in_view: "0",
    gnss_sats_used: "0",
    glonass_sats_used: "",
    reserved3: "",
    c_n0_max: "0",
    hpa: "",
    vpa: ""
  ]
  @response_keys Keyword.keys(@response_fields)
  defstruct @response_fields

  @gps_info_response "+CGNSINF: "

  def from_raw_response(@gps_info_response <> <<gps_data::binary>>) do
    data =
      gps_data
      |> String.split(",")

    kv = Enum.zip(@response_keys, data)
    struct!(%Fona.GpsResponse{}, kv)
  end
end
