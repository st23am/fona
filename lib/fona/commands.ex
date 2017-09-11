defmodule Fona.Commands do
  require Logger

  def open_serial_connection(pid, device_path) do
    Nerves.UART.open(pid, device_path, speed: 115200, active: false)
  end

  def configure_serial_connection(pid) do
    Nerves.UART.configure(pid, framing: {Nerves.UART.Framing.Line, separator: "\r\n"})
    Nerves.UART.write(pid, "ATE0")
    read_until_expected(pid, "OK")
    Nerves.UART.write(pid, "AT+CMEE=2")
    read_until_expected(pid, "OK")
    Nerves.UART.flush(pid)
  end

  def enable_gprs(pid, apn, username, password) do
    Nerves.UART.flush(pid)
    Nerves.UART.drain(pid)
    with {:ok, "+CGREG: 0,1"} <- command_with_result(pid, "AT+CGREG?"),
         {:ok, "+CGATT: 1"}   <- command_with_result(pid, "AT+CGATT?") do

         {:ok, "CONNECTED"}
    else
      _ ->
      with {:ok, "OK"}          <- cast_command(pid, "AT"),
           {:ok, "OK"}          <- cast_command(pid, "ATH"),
           {:ok, "SHUT OK"}     <- command_with_alt_success(pid, "AT+CIPSHUT"),
           {:ok, "OK"}          <- cast_command(pid, "AT+CGATT=1"),
           {:ok, "OK"}          <- cast_command(pid, "AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\""),
           {:ok, "OK"}          <- cast_command(pid, "AT+SAPBR=3,1,\"APN\",\"#{apn}\""),
           {:ok, "OK"}          <- cast_command(pid, "AT+CSTT=\"#{username}\"#{password}\""),
           {:ok, "OK"}          <- cast_command(pid, "AT+CIICR"),
           {:ok, "+CGATT: 1"}   <- command_with_result(pid, "AT+CGATT?"),
           {:ok, "+CGREG: 0,1"} <- command_with_result(pid, "AT+CGREG?") do
        Logger.info("Serial Connection Started")
        Logger.info("GPRS Connection Enabled")
        {:ok, "CONNECTED"}
      else
        error ->
          Logger.error("An Error: #{inspect error} Occurred while enabling GPRS")
          Logger.error("Closing GPRS Connection...")
          close_gprs_connection(pid)
          {:error, "DISCONNECTED"}
      end
    end
  end

  def close_gprs_connection(pid) do
    :ok = write_to_fona(pid, "AT+SAPBR=0,1")
    {:ok, ""} = read_from_fona(pid, 3000)
    {:ok, "OK"} = read_from_fona(pid, 3000)
    {:ok, "OK"} = cast_command(pid, "AT+CGATT=0")
  end

  def gps_power_status(pid) do
    case command_with_result(pid, "AT+CGNSPWR?") do
      {:ok, "+CGNSPWR: 0"} -> {:ok, "GPS OFF"}
      {:ok, "+CGNSPWR: 1"} -> {:ok, "GPS ON"}
    end
  end

  def toggle_gps(pid) do
    case command_with_result(pid, "AT+CGNSPWR?") do
      {:ok, "+CGNSPWR: 0"} ->
        {:ok, "OK"} = cast_command(pid, "AT+CGNSPWR=1")
        {:ok, "GPS ON"}
      {:ok, "+CGNSPWR: 1"} ->
        {:ok, "OK"} = cast_command(pid, "AT+CGNSPWR=0")
        {:ok, "GPS OFF"}
    end
  end

  def gps_location(pid) do
    command_with_result(pid, "AT+CGNSINF")
  end

  def send_tcp_msg(pid, dest, port, msg) when is_binary(msg) do
    Nerves.UART.flush(pid)
    Nerves.UART.drain(pid)
    read_until_expected(pid, "")
    write_to_fona(pid, "AT+CIPSPRT=2")
    read_until_expected(pid, "OK")
    write_to_fona(pid, "AT+CIPSHUT")
    read_until_expected(pid, "SHUT OK")
    write_to_fona(pid, "AT+CIPMUX=0")
    read_until_expected(pid, "OK")
    write_to_fona(pid, "AT+CIPRXGET=1")
    read_until_expected(pid, "OK")
    write_to_fona(pid,"AT+CIPSTART=\"TCP\",\"#{dest}\",\"#{port}\"")
    read_until_expected(pid, "CONNECT OK")
    write_to_fona(pid, "AT+CIPSEND=#{byte_size(msg)}")
    read_from_fona(pid, 2000)
    write_to_fona(pid, msg)
    read_from_fona(pid, 2000)
    write_to_fona(pid, "\x1a")
    case read_until_expected(pid,  "+CIPRXGET: 1") do
      {:ok, "+CIPRXGET: 1"} ->
        write_to_fona(pid,"AT+CIPCLOSE")
        read_until_expected(pid, "CLOSE OK")
      {:ok, "ERROR"} ->
        read_from_fona(pid, 3000)
        read_from_fona(pid, 3000)
        {:ok, "ERROR"}
      _ ->
        {:ok, "ERROR"}
    end
  end

  def attach_network(pid) do
    {:ok, "OK"} = cast_command(pid, "AT+SAPBR=1,1")
  end


  def get_imei(pid) do
    command_with_result(pid, "AT+GSN")
  end

  # TODO handle these better with framing
  defp cast_command(pid, command) do
    :ok = write_to_fona(pid, command)
    result = read_until_expected(pid, "OK")
    case result do
      {:ok, "OK"} -> {:ok, "OK"}
      {:ok, "ERROR"} ->
        Logger.info("Command #{command} Error Retrying Again")
        retry_cast_command(pid, command, 1)
    end
  end

  defp command_with_result(pid, command) do
    :ok = write_to_fona(pid, command)
    read_until_result(pid)
  end

  defp command_with_alt_success(pid, command) do
    :ok = write_to_fona(pid, command)
    {:ok, ""} = read_from_fona(pid)
    read_from_fona(pid)
  end

  defp retry_cast_command(pid, command, num_tries) do
    if num_tries < 4 do
      Logger.info("Writing #{command} to Fona")
      :ok = write_to_fona(pid, command)
      {:ok, ""} = read_from_fona(pid)
      case read_from_fona(pid) do
        {:ok, "OK"} -> {:ok, "OK"}
        {:ok, "ERROR"} ->
          retry_cast_command(pid, command, num_tries + 1)
      end
    else
      Logger.info("Writting #{command} Failed 4 times Giving up")
      {:ok, "ERROR"}
    end
  end

  defp write_to_fona(pid, command) do
    Logger.info("Writing #{command} to Fona")
    Nerves.UART.write(pid, command)
  end

  defp read_from_fona(pid, timeout \\ 6000) do
    result = Nerves.UART.read(pid, timeout)
    Logger.info("Got Back #{inspect result} from Fona")
    result
  end

  defp read_until_result(pid) do
    result = read_from_fona(pid, 2000)
    case result do
      {:ok, ""} -> read_until_result(pid)
      {:ok, result} ->
        read_until_expected(pid, "OK")
        {:ok, result}
    end
  end

  defp read_until_expected(pid, expected) do
    result = read_from_fona(pid, 2000)
    case result  do
      {:ok, ^expected} -> {:ok, expected}
      {:ok, "ERROR"} -> {:ok, "ERROR"}
      {:ok, "+CME ERROR: operation not allowed"} -> {:ok, "ERROR"}
      {:ok, "SIM808 R14.18"} -> {:ok, "ERROR"}
      {:ok, "STATE: PDP DEACT"} -> {:ok, "ERROR"}
      {:ok, "CONNECT FAIL"} -> {:ok, "ERORR"}
      {:ok, "CLOSED"} -> {:ok, "ERROR"}
      {:error, :ebadf} -> {:ok, "ERROR"}
      {:ok, "STATE: IP STATUS"} -> {:ok, "ERROR"}
      _         ->
        read_until_expected(pid, expected)
    end
  end
end
