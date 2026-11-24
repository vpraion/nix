{ ... }:

{
  # Realtime Kit priority daemon for low-latency audio scheduling.
  security.rtkit.enable = true;

  # Disable legacy PulseAudio daemon in favor of PipeWire.
  services.pulseaudio.enable = false;

  # Modern unified PipeWire sound server.
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Common Unix Printing System (CUPS).
  services.printing.enable = true;
}
