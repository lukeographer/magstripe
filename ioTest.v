`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
//Created by Luke Grantham 
//REDID: 818681559
//Date: 1/31/2019
//For: Lab 1 COMPE470L Spring 2019
//////////////////////////////////////////////////////////////////////////////////
module outputBinary(
	input clk,
	input btnU, btnD, btnR,
	input [7:0] JB,
	input [15:0] sw,
	output [7:0] JA,
	output reg [15:0] led
	 );
	 
localparam Idle = 4'b0000,  //0
           BeginZeros = 4'b0001, //1
           BeginZeroFill = 4'b0010, //2
           SendTrack2 = 4'b0011, //3
           FillTrack2 = 4'b0100, //4
           EndTrack2Zeros = 4'b0101, //5
           EndTrack2ZerosFill = 4'b0110, //6
           SendTrack3 = 4'b1000, //8
           FillTrack3 = 4'b1001,  //9
           EndTrack3Zeros = 4'b1010, //10
           EndTrack3ZerosFill = 4'b1011, //11
           Pause = 4'b1100, //12
           Track3Zeros = 4'b1101, //13
           PauseZeroFill = 4'b1110, //14
           Test = 4'b0111; //7
 
//parameters for track lengths in bits           
localparam track2Length = 159;
localparam track3Length = 59;

//Registers to store values
reg [3:0] State = 0;
reg [19:0] cnt1 = 0;
reg [3:0] pCnt = 0;
reg [4:0] pReg = 0;
reg [59:0] intro = 60'h000000000000000;
reg [track2Length:0] Track2 = 160'hb6220900010249060d49121200000026853300fa; //9 should be at end
reg [track3Length:0] Track3 = 60'hb813969592d40ff; //3 should be at end. 
reg[79:0] testBits = 80'h00000000000000000000;
reg out = 0;
reg [3:0] OutChar = 4'hb;
reg notOut = 0;
reg en = 0;
reg [15:0] ndx1 = 0;
reg [15:0] ndx3 = 3;
reg [15:0] ndx2 = track2Length; 
reg [15:0] pauseCnt = 0;
reg [15:0] testndx = 0;

//output assignments
assign JA[0] = out;
assign JA[1] = out ^ 1;
assign JA[2] = en;

//TODO


//END TODO
//Always block for the emulator state machine
always @(posedge clk) begin
    //counter to emulate the speed of a card swipe. 
    if(cnt1 == 3) begin //30000 for not sim
        cnt1 <= 0; //reset count
        case (State) //case statemet for FSM
            Idle: begin //Idle state constantly polling for button trigger
                out <= 1'b0; //set out to zero
                en <= 1'b0; //disable H-Bridge IC
                if (btnU) begin //btnU triggers the sequence
                    State <= BeginZeroFill; //state change to initial zeroes
                    en <= 1'b1; //enable H-Bridge IC
                end
                if (btnR) begin //btnR triggers trasition to send zeroes as a test
                    State <= Test; //transition to test state   
                    en <= 1'b1; //enable H-Bridge IC
                end
                if (btnD) begin //btnD shows the first byte of data of the track on LED. 
                    led[7:0] <= Track2[7:0];
                end
                else 
                    led[7:0] <= 0;
            end
            BeginZeros: begin //first, send zeroes to synchronize 
                if (intro[ndx1]) //if output is a 1, output is switched
                    out <= out ^ 1;
                led[0] <= 1'b1; //external feedback
                ndx1 <= ndx1 + 1;  //increment counter
                if (ndx1 >= 40) begin //when 10 zeroes are outputted, transition to sending data
                    State <= FillTrack2; 
                    ndx1 <= 0; //reset counter
                end
                else
                    State <= BeginZeroFill; //transition to fill state
            end
            BeginZeroFill: begin //switch output to signal next index
                out <= out ^ 1; //switch output
                State <= BeginZeros; //transition back to sending state
            end
            SendTrack2: begin //Track2 is sent here
                if(pCnt > 3) begin //parity bit counter for 4 bits
                    pCnt <= 0; //reset parity bit counter
                    //concatenate track2 bits to view output in waveforms
                    OutChar <= {Track2[ndx2],Track2[ndx2-1],Track2[ndx2-2], Track2[ndx2-3]}; 
                    if ((pReg % 2) == 0) begin //odd parity evaulation
                        pReg <= 0; //reset one bit accumulator
                        out <= out ^ 1; //invert output
                        State <= FillTrack2; //transition to fill state
                    end
                    else begin
                        pReg <= 0; //reset one bit accumulator
                        State <= FillTrack2; //transition to fill state
                    end
                        
                end
                else begin
                      
                    if (ndx2 == 16'hffff) begin //when end of track is reached
                        ndx2 <= track3Length; //update counter for track3
                        out <= 1'b0; //output is 0
                        OutChar <= 4'hb; //view first bit in waveform of track3
                        pCnt <= 4'h0; //reset parity counter
                        pReg <= 0; //reset parity accumulator
                        State <= EndTrack2ZerosFill; //transition to exit zeros state
                        
                    end
                    else begin
                        pCnt <= pCnt + 1; //increment parity counter
                        if (OutChar[pCnt]) begin//if bit is 1
                            out <= out ^ 1; //invert output
                            pReg <= pReg + 1; //increment parity accumulator
                        end
                        led[1] <= 1'b1; //feedback to see track2 is being outputted
                        led[0] <= 1'b0; //feedback to see track1 has stopped output
                        ndx2 <= ndx2 - 1; //decrement track3 index
                        State <= FillTrack2; //transition to fill state
                    end
                end
            end
            FillTrack2: begin //switch output to signal index
                out <= out ^ 1; //invert ouptut 
                State <= SendTrack2; //transition back to send next bit
            end
            EndTrack2Zeros: begin //output zeroes to indicate end of track2
                if (intro[ndx1]) //if bit is 1
                    out <= out ^ 1; //output is switched
                led[0] <= 1'b1; //feedback
                ndx1 <= ndx1 + 1;  //increment counter index
                if (ndx1 >= 5) begin //when zeros are finished
                    ndx1 <= 0; //reset counter index
                    State <= Pause; //transiiton to pause state
                    en <= 1'b0; // disable H-Bridge
                end
                else
                    State <= EndTrack2ZerosFill; //fill state transition
            end
            EndTrack2ZerosFill: begin //fill state
                out <= out ^ 1; //invert output
                State <= EndTrack2Zeros; //transition to zeros state
            end
            Pause: begin //pause state
                if(pauseCnt >= 90) begin //when pause counter is 10
                    pauseCnt <= 0; //reset pause counter
                    State <= Track3Zeros; //transition to Track3 Zeros
                    pauseCnt <= 0; //reset pause counter
                    en <= 1'b1; //enable H-Bridge IC
                end
                else
                    pauseCnt <= pauseCnt + 1; //increment pause counter
            end
            Track3Zeros: begin //state to synchronize for third track
                if (intro[ndx1]) //if bit is 1
                    out <= out ^ 1; //invert output
                led[0] <= 1'b1; //feedback
                ndx1 <= ndx1 + 1; //increment counter
                if (ndx1 >= 30) begin //if 20 zeros sent
                    State <= FillTrack3; //transition to send track3
                    ndx1 <= 0; //reset counter
                end
                else
                    State <= PauseZeroFill; //transition to fill state
            end
            PauseZeroFill: begin
                out <= out ^ 1; //invert output
                State <= Track3Zeros; //transition to zeros state
            end
            SendTrack3: begin //track3 being sent
                if(pCnt > 3) begin //if parity counter reaches 3
                    pCnt <= 0; //reset parity counter
                    //view output character in waveform
                    OutChar <= {Track3[ndx2],Track3[ndx2 - 1],Track3[ndx2 - 2], Track3[ndx2 - 3]}; 
                    if ((pReg % 2) == 0) begin //odd parity generator
                        pReg <= 0; //reset parity accumulator
                        out <= out ^ 1; //invert output
                        State <= FillTrack3; //transition to fill state
                    end
                    else begin
                        pReg <= 0; //reset parity accumulator
                        State <= FillTrack3; //trasition to fill state
                    end
                        
                end
                else begin
                    if (ndx2 == 16'hffff) begin //when track3 ends
                        ndx2 <= track2Length; //reset index
                        State <= EndTrack3ZerosFill; //transition to zeroes state
                        pCnt <= 0; //reset parity counter
                        
                    end
                    else begin
                        pCnt <= pCnt + 1; //increment parity counter
                        if (OutChar[pCnt]) begin //if output bit is 1
                            out <= out ^ 1; //invert output
                            pReg <= pReg + 1; //increment parity accumulator
                        end
                        led[1] <= 1'b1; //feedback
                        led[0] <= 1'b0; //feedback
                        ndx2 <= ndx2 - 1; //decrement index
                        State <= FillTrack3; //transition to fill state
                    end
                end
            end
            FillTrack3: begin
                out <= out ^ 1; //invert output
                State <= SendTrack3; //transition to track3 output state
            end
            EndTrack3Zeros: begin
                if (intro[ndx1]) //if bit is 1
                    out <= out ^ 1; //invert output
                led[0] <= 1'b1; //feedback
                ndx1 <= ndx1 + 1;  //increment index
                if (ndx1 >= 10) begin //when 10 zeros are sent
                    ndx1 <= 0; //reset counter
                    OutChar = 4'hb; //output for waveform viewer
                    State <= Idle; //transition to idle
                end
                else
                    State <= EndTrack3ZerosFill; //transition to fill state
            end
            EndTrack3ZerosFill: begin
                out <= out ^ 1; //invert output
                State <= EndTrack3Zeros; //transition to track3 zeroes 
            end
            Test: begin //test state to send output zero
                out <= testBits[testndx]; //output is zero
                led[0] <= 1'b1; //feedback
                testndx <= testndx + 1;  //incremement index
                if (testndx >= 5) begin //when 10 has been sent
                    testndx <= 0; //reset index
                    State <= Idle; //transition to idle state
                end
            end
        endcase
    end
    else
        cnt1 <= cnt1 + 1; //increment counter
 
end 

endmodule