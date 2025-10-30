//---------------------------------------------------------------------------
// Author: Kwesi Buabeng Debrah
// Date  : Apr 10, 2025
//
// Description: 
//  Defines macros for register file memory mapping.
//---------------------------------------------------------------------------


//---------------------------------------------------------------------------
// Read-Write
//---------------------------------------------------------------------------
`define map(signal, addr) \
    row = (addr >> 3); \
    lsb = addr % 8; \
	signal = rf_in[row][8*lsb +: $bits(signal)]; \
	rf_out[row][8*lsb +: $bits(signal)] = signal;


//---------------------------------------------------------------------------
// Read-Only
//---------------------------------------------------------------------------
`define map_ro(signal, addr) \
    row = (addr >> 3); \
    lsb = addr % 8; \
	rf_out[row][8*lsb +: $bits(signal)] = signal;


//---------------------------------------------------------------------------
// Read-Write Pulse
//---------------------------------------------------------------------------
`define map_pulse(signal, addr, polarity=1) \
    row = (addr >> 3); \
    lsb = addr % 8; \
	signal = hsel & hwrite & htrans[1] & wr_en[lsb] & (haddr[RF_AWIDTH-1:3] == row); \
    signal = (polarity) ? signal : !signal; // Invert the signal if needed


//---------------------------------------------------------------------------
// Read-Only Pulse
//---------------------------------------------------------------------------
`define map_pulse_ro(signal, addr, polarity=1) \
    row = (addr >> 3); \
    lsb = addr % 8; \
	signal = hsel & !hwrite & htrans[1] & (haddr[RF_AWIDTH-1:3] == row) & (haddr[2:0] == lsb); \
    signal = (polarity) ? signal : !signal; // Invert the signal if needed

//---------------------------------------------------------------------------
// Read-Only Pulse No Delay (Without Address Phase Delay)
//---------------------------------------------------------------------------
`define map_pulse_ro_nd(signal, addr, polarity=1) \
    row = (addr >> 3); \
    lsb = addr % 8; \
	signal = sel & !write & trans[1] & (addr[RF_AWIDTH-1:3] == row) & (addr[2:0] == lsb); \
    signal = (polarity) ? signal : !signal; // Invert the signal if needed
    