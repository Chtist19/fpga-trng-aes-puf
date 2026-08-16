set_property PACKAGE_PIN AE5 [get_ports sys_clk_p]
set_property PACKAGE_PIN AF5 [get_ports sys_clk_n]
set_property IOSTANDARD DIFF_HSTL_I_12 [get_ports sys_clk_p]
set_property IOSTANDARD DIFF_HSTL_I_12 [get_ports sys_clk_n]
create_clock -period 10.000 -name sys_clk [get_ports sys_clk_p]

set_property PACKAGE_PIN F13 [get_ports sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports sys_rst_n]

set_property PACKAGE_PIN C12 [get_ports uart_txd]
set_property IOSTANDARD LVCMOS33 [get_ports uart_txd]

set_property PACKAGE_PIN H13 [get_ports {led[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[0]}]

set_property PACKAGE_PIN G13 [get_ports {led[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {led[1]}]
