// bsv libraries
import SpecialFIFOs::*;
import Vector::*;
import StmtFSM::*;
import FIFO::*;

// portz libraries
import CtrlMux::*;
import Portal::*;
import ConnectalMemory::*;
import MemTypes::*;
import MemServer::*;
import MMU::*;
import Leds::*;
import DmaUtils::*;
import HDMI::*;
import PS7LIB::*;
import HostInterface::*;

// generated by tool
import DmaDebugRequest::*;
import MMUConfigRequest::*;
import DmaDebugIndication::*;
import MMUConfigIndication::*;
import HdmiDisplayRequest::*;
import HdmiDisplayIndication::*;
import HdmiInternalIndication::*;
import HdmiInternalRequest::*;

// defined by user
import HdmiDisplay::*;

typedef enum {HdmiDisplayRequest, HdmiDisplayIndication, HdmiInternalRequest, HdmiInternalIndication, HostDmaDebugIndication, HostDmaDebugRequest, HostMMUConfigRequest, HostMMUConfigIndication} IfcNames deriving (Eq,Bits);

typedef HDMI#(Bit#(16)) HDMI16;

module mkConnectalTop#(HostType host)(ConnectalTop#(PhysAddrWidth,64,HDMI#(Bit#(16)),1));

`ifdef ZynqHostTypeIF
   Clock clk1 = host.fclkclk[1];
`else
   Clock clk1 <- exposeCurrentClock();
`endif
   HdmiInternalIndicationProxy hdmiInternalIndicationProxy <- mkHdmiInternalIndicationProxy(HdmiInternalIndication);
   HdmiDisplayIndicationProxy hdmiDisplayIndicationProxy <- mkHdmiDisplayIndicationProxy(HdmiDisplayIndication);
   HdmiDisplay hdmiDisplay <- mkHdmiDisplay(clk1, hdmiDisplayIndicationProxy.ifc, hdmiInternalIndicationProxy.ifc);
   HdmiDisplayRequestWrapper hdmiDisplayRequestWrapper <- mkHdmiDisplayRequestWrapper(HdmiDisplayRequest,hdmiDisplay.displayRequest);
   HdmiInternalRequestWrapper hdmiInternalRequestWrapper <- mkHdmiInternalRequestWrapper(HdmiInternalRequest,hdmiDisplay.internalRequest);

   Vector#(1,  MemReadClient#(64))   readClients = cons(hdmiDisplay.dmaClient, nil);
   MMUConfigIndicationProxy hostMMUConfigIndicationProxy <- mkMMUConfigIndicationProxy(HostMMUConfigIndication);
   MMU#(PhysAddrWidth) hostMMU <- mkMMU(0, True, hostMMUConfigIndicationProxy.ifc);
   MMUConfigRequestWrapper hostMMUConfigRequestWrapper <- mkMMUConfigRequestWrapper(HostMMUConfigRequest, hostMMU.request);

   DmaDebugIndicationProxy hostDmaDebugIndicationProxy <- mkDmaDebugIndicationProxy(HostDmaDebugIndication);
   MemServer#(PhysAddrWidth,64,1) dma <- mkMemServerR(hostDmaDebugIndicationProxy.ifc, readClients, cons(hostMMU,nil));
   DmaDebugRequestWrapper hostDmaDebugRequestWrapper <- mkDmaDebugRequestWrapper(HostDmaDebugRequest, dma.request);

   Vector#(8,StdPortal) portals;
   portals[0] = hdmiDisplayRequestWrapper.portalIfc;
   portals[1] = hdmiDisplayIndicationProxy.portalIfc;
   portals[2] = hdmiInternalRequestWrapper.portalIfc;
   portals[3] = hdmiInternalIndicationProxy.portalIfc; 
   portals[4] = hostDmaDebugRequestWrapper.portalIfc;
   portals[5] = hostDmaDebugIndicationProxy.portalIfc; 
   portals[6] = hostMMUConfigRequestWrapper.portalIfc;
   portals[7] = hostMMUConfigIndicationProxy.portalIfc;
   let ctrl_mux <- mkSlaveMux(portals);
   
   interface interrupt = getInterruptVector(portals);
   interface slave = ctrl_mux;
   interface masters = dma.masters;
   //interface xadc = hdmiDisplay.xadc;
   interface pins = hdmiDisplay.hdmi;      
endmodule : mkConnectalTop

import "BDPI" function Action bdpi_hdmi_vsync(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_hsync(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_de(Bit#(1) v);
import "BDPI" function Action bdpi_hdmi_data(Bit#(16) v);
module mkResponder#(HDMI#(Bit#(16)) pins)(Empty);
    rule hvconv;
        bdpi_hdmi_vsync(pins.hdmi_vsync);
    endrule
    rule hvconh;
        bdpi_hdmi_hsync(pins.hdmi_hsync);
    endrule
    rule hvconde;
        bdpi_hdmi_de(pins.hdmi_de);
    endrule
    rule hvcond;
        bdpi_hdmi_data(pins.hdmi_data);
    endrule
endmodule
