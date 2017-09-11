# Fona

A library for controlling the [Fona 808 Shield](https://www.adafruit.com/product/2542) by Adafruit Industries
Documentation for the Fona can be found [HERE](https://learn.adafruit.com/adafruit-fona-808-cellular-plus-gps-breakout/downloads)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `fona` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:fona, "~> 0.1.0"}]
end
```

## Examples

For this example I am using a [Adafruit CP2104](https://www.adafruit.com/product/3309) Friend to connect to the Fona and a SIM from [Ting](https://ting.com/shop/gsmSIM)

### Connecting to the Fona
```
Erlang/OTP 20 [erts-9.0] [source] [64-bit] [smp:8:8] [ds:8:8:10] [async-threads:10] [hipe] [kernel-poll:false] [dtrace]

Interactive Elixir (1.5.1) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> Fona.connect("/dev/cu.SLAB_USBtoUART")

17:46:04.624 [info]  Connecting...

17:46:04.648 [info]  Got Back {:ok, ""} from Fona

17:46:04.648 [info]  Got Back {:ok, "OK"} from Fona

17:46:04.652 [info]  Got Back {:ok, ""} from Fona

17:46:04.652 [info]  Got Back {:ok, "OK"} from Fona

17:46:04.652 [info]  Writing AT+CGNSPWR? to Fona

17:46:04.657 [info]  Got Back {:ok, ""} from Fona

17:46:04.657 [info]  Got Back {:ok, "+CGNSPWR: 1"} from Fona

17:46:04.657 [info]  Got Back {:ok, ""} from Fona

17:46:04.658 [info]  Got Back {:ok, "OK"} from Fona

17:46:04.658 [info]  Connected. Fona awaiting commands
{:ok, #PID<0.161.0>}
```

### Connecting to the GPRS network 

```
iex(2)> Fona.connect_to_network("wholesale", "", "")

17:47:10.229 [info]  Writing AT+CGREG? to Fona

17:47:10.234 [info]  Got Back {:ok, ""} from Fona

17:47:10.234 [info]  Got Back {:ok, "+CGREG: 0,1"} from Fona

17:47:10.235 [info]  Got Back {:ok, ""} from Fona

17:47:10.235 [info]  Got Back {:ok, "OK"} from Fona

17:47:10.235 [info]  Writing AT+CGATT? to Fona

17:47:10.240 [info]  Got Back {:ok, ""} from Fona

17:47:10.240 [info]  Got Back {:ok, "+CGATT: 1"} from Fona

17:47:10.240 [info]  Got Back {:ok, ""} from Fona

17:47:10.240 [info]  Got Back {:ok, "OK"} from Fona
%{device_path: "/dev/cu.SLAB_USBtoUART", gprs_status: "CONNECTED",
  gps_power: "GPS ON", serial_pid: #PID<0.162.0>}
```

### Getting a GPS Location

```
iex(3)> location = Fona.gps_location

17:56:55.585 [info]  Writing AT+CGNSINF to Fona

17:56:55.599 [info]  Got Back {:ok, ""} from Fona

17:56:55.599 [info]  Got Back {:ok, "+CGNSINF: 1,1,20170911005654.000,47.617015,-122.201292,118.600,0.50,140.2,1,,2.2,2.4,1.0,,12,6,,,20,,"} from Fona

17:56:55.599 [info]  Got Back {:ok, ""} from Fona

17:56:55.599 [info]  Got Back {:ok, "OK"} from Fona
%Fona.GpsResponse{altitude: "118.600", c_n0_max: "20", course: "140.2",
 datetime: "20170911005654.000", fix_mode: "1", fix_status: "1",
 glonass_sats_used: "", gnss_sats_in_view: "12", gnss_sats_used: "6",
 hdop: "2.2", hpa: "", latitude: "47.617015", longitude: "-122.201292",
 pdop: "2.4", reserved1: "", reserved2: "", reserved3: "", run_status: "1",
 speed: "0.50", vdop: "1.0", vpa: ""}
iex(4)>
```

### sending a TCP/IP message to a server

```
iex(4)> message = "test,#{location.datetime},#{location.latitude},#{location.longitude},#{location.course}"
 "test,20170911005654.000,47.617015,-122.201292,140.2"
iex(5)> Fona.send_tcp_msg(YOUR_URL", "YOUR_PORT", message)

18:01:56.933 [info]  Got Back {:ok, ""} from Fona

18:01:56.933 [info]  Writing AT+CIPSPRT=2 to Fona

18:01:56.938 [info]  Got Back {:ok, ""} from Fona

18:01:56.938 [info]  Got Back {:ok, "OK"} from Fona

18:01:56.938 [info]  Writing AT+CIPSHUT to Fona

18:01:57.334 [info]  Got Back {:ok, ""} from Fona

18:01:57.334 [info]  Got Back {:ok, "SHUT OK"} from Fona

18:01:57.334 [info]  Writing AT+CIPMUX=0 to Fona

18:01:57.339 [info]  Got Back {:ok, ""} from Fona

18:01:57.339 [info]  Got Back {:ok, "OK"} from Fona

18:01:57.339 [info]  Writing AT+CIPRXGET=1 to Fona

18:01:57.344 [info]  Got Back {:ok, ""} from Fona

18:01:57.344 [info]  Got Back {:ok, "OK"} from Fona

18:01:57.344 [info]  Writing AT+CIPSTART="TCP","YOUR_URL","YOUR_PORT" to Fona

18:01:57.352 [info]  Got Back {:ok, ""} from Fona

18:01:57.352 [info]  Got Back {:ok, "OK"} from Fona

18:01:58.371 [info]  Got Back {:ok, ""} from Fona

18:01:58.371 [info]  Got Back {:ok, "CONNECT OK"} from Fona

18:01:58.371 [info]  Writing AT+CIPSEND=51 to Fona

18:02:00.374 [info]  Got Back {:ok, ""} from Fona

18:02:00.375 [info]  Writing test,20170911005654.000,47.617015,-122.201292,140.2 to Fona

18:02:01.531 [info]  Got Back {:ok, ""} from Fona

18:02:01.531 [info]  Writing ^Z to Fona

18:02:01.531 [info]  Got Back {:ok, "+CIPRXGET: 1"} from Fona

18:02:01.531 [info]  Writing AT+CIPCLOSE to Fona

18:02:01.655 [info]  Got Back {:ok, ""} from Fona

18:02:01.655 [info]  Got Back {:ok, "CLOSE OK"} from Fona
{:ok, "SENT"}
```


Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/fona](https://hexdocs.pm/fona).

