set PERIOD 10000
set Clk_Top $DESIGN
set Clk_Domain $DESIGN
set Clk_Name myCLK
set Clk_Latency 500
set Clk_Rise_Uncertainty 500
set Clk_Fall_Uncertainty 500
set Clk_Slew 500
set Input_Delay 500
set Output_Delay 500

define_clock -name $Clk_Name -period $PERIOD -design $Clk_Top -domain $Clk_Domain [find / -port clk]

set_attribute clock_network_late_latency $Clk_Latency $Clk_Name
set_attribute clock_source_late_latency $Clk_Latency $Clk_Name

set_attribute clock_setup_uncertainty $Clk_Latency $Clk_Name
set_attribute clock_hold_uncertainty $Clk_Latency $Clk_Name

set_attribute slew_rise $Clk_Rise_Uncertainty $Clk_Name
set_attribute slew_fall $Clk_Fall_Uncertainty $Clk_Name

external_delay -input $Input_Delay -clock [find / clock $ClkName] -name in_con [find /des* -port ports_in/*]
external_delay -output $Output_Delay -clock [find / clock $ClkName] -name out_con [find /des* -port ports_out/*]