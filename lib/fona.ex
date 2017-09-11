defmodule Fona do
  @moduledoc """
  Documentation for Fona.
  """
  use GenServer
  require Logger
  alias Fona.Commands

  # CLIENT
  def connect(device_path) do
    start_link(device_path)
  end

  def connect_to_network(apn, username \\ "", password \\ "") do
    GenServer.call(__MODULE__, {:enable_gprs, apn, username, password}, 20000)
  end

  def shutdown_network() do
    GenServer.call(__MODULE__, :close_gprs_connection)
  end

  def toggle_gps_power do
    GenServer.call(__MODULE__, :toggle_gps)
  end

  def gps_power_status do
    GenServer.call(__MODULE__, :gps_power_status)
  end

  def gps_has_fix? do
    case GenServer.call(__MODULE__, :gps_location) do
      {:ok, "+CGNSINF: 1,1" <> <<_rest::binary>>} ->
        true
      _  ->
        false
    end
  end

  def gps_location do
    {:ok, reponse} = GenServer.call(__MODULE__, :gps_location)
    Fona.GpsResponse.from_raw_response(reponse)
  end

  def device_status do
    GenServer.call(__MODULE__, :device_status)
  end

  def send_tcp_msg(dest, port, msg) do
    GenServer.call(__MODULE__, {:send_tcp_msg, dest, port, msg}, :infinity)
  end

  def get_imei do
    GenServer.call(__MODULE__, :get_imei)
  end

  # SERVER

  def start_link(device_path) do
    GenServer.start_link(__MODULE__, %{device_path: device_path}, name: __MODULE__)
  end

  def init(%{device_path: device_path}) do
    {:ok, pid} = Nerves.UART.start_link()
    Logger.info("Connecting...")
    :ok = Commands.open_serial_connection(pid, device_path)
    :ok = Commands.configure_serial_connection(pid)
    {:ok, gps_power} = Commands.gps_power_status(pid)
    Logger.info("Connected. Fona awaiting commands")
    {:ok, %{serial_pid: pid, gps_power: gps_power, gprs_status: nil, device_path: device_path}}
  end

  def handle_call({:enable_gprs, apn, username, password}, _from, %{serial_pid: pid} = state) do
    connection_state = with {:ok, "CONNECTED"} <- Commands.enable_gprs(pid, apn, username, password) do
                         Map.put(state, :gprs_status, "CONNECTED")
                       else
                         {:error, "DISCONNECTED"} ->
                           Map.put(state, :gprs_status, "DISCONNECTED")
                       end
    {:reply, connection_state, connection_state}
  end

  def handle_call(:close_gprs_connection, _from, %{serial_pid: pid} = state) do
    Commands.close_gprs_connection(pid)
    connection_state = Map.put(state, :gprs_status, "Disconnected")
    {:reply, connection_state, connection_state}
  end

  def handle_call(:toggle_gps, _from, %{serial_pid: pid} = state) do
    status = case Commands.toggle_gps(pid) do
      {:ok, "GPS ON"} -> Map.put(state, :gps_power, "GPS ON")
      {:ok, "GPS OFF"} -> Map.put(state, :gps_power, "GPS OFF")
    end
    {:reply, status, status}
  end

  def handle_call(:gps_power_status, _from, %{serial_pid: pid} = state) do
    status = Commands.gps_power_status(pid)
    {:reply, status, state}
  end

  def handle_call(:gps_location, _from, %{serial_pid: pid} = state) do
    location = Commands.gps_location(pid)
    {:reply, location, state}
  end

  def handle_call({:send_tcp_msg, dest, port, msg}, _from, %{serial_pid: pid} = state) do
    result = case Commands.send_tcp_msg(pid, dest, port, msg) do
      {:ok, "CLOSE OK"} -> {:ok, "SENT"}
      {:ok, "ERROR"} -> {:error, "ERROR"}
    end
    {:reply, result, state, 30_000}
  end

  def handle_call(:device_status, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:get_imei, _from, %{serial_pid: pid} = state) do
    imei = Commands.get_imei(pid)
    {:reply, imei, state}
  end
end
