library ieee;
use ieee.std_logic_1164.all;


entity trng_core is
  port (
    clk_i    : in  std_logic;
    rstn_i   : in  std_logic;
    enable_i : in  std_logic;
    valid_o  : out std_logic;
    data_o   : out std_logic_vector(7 downto 0)
  );
end trng_core;

architecture rtl of trng_core is
  signal valid_u : std_ulogic;
  signal data_u  : std_ulogic_vector(7 downto 0);
begin

  u_neoTRNG: entity work.neoTRNG
    generic map (
      NUM_CELLS     => 3,
      NUM_INV_START => 5,
      NUM_RAW_BITS  => 64,
      SIM_MODE      => false
    )
    port map (
      clk_i    => clk_i,
      rstn_i   => rstn_i,
      enable_i => enable_i,
      valid_o  => valid_u,
      data_o   => data_u
    );

  valid_o <= std_logic(valid_u);
  data_o  <= std_logic_vector(data_u);

end rtl;
