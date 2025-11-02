module VGA #(
    parameter integer H_active = 640,
    parameter integer Back_Porch_H = 48,
    parameter integer Front_Porch_H = 16,
    parameter integer Hsync = 96,

    parameter integer V_active = 480,
    parameter integer Back_Porch_V = 33,
    parameter integer Front_Porch_V = 10,
    parameter integer Vsync = 2
)(
    input wire pixel_clock, 
    input wire rst_n,
    output wire hsync,
    output wire vsync,
    output wire de,
    output reg[$clog2(H_active) - 1:0] x,
    output reg[$clog2(V_active) - 1:0] y
);


// counters    
localparam integer H_total = H_active + Back_Porch_H + Front_Porch_H + Hsync;
localparam integer V_total = V_active + Back_Porch_V + Front_Porch_V + Vsync;
reg [$clog2(H_total) - 1: 0] pixel_counter_x;
reg [$clog2(V_total) - 1: 0] pixel_counter_y;



always @(posedge pixel_clock or negedge rst_n) begin
    if (!rst_n) begin  
        pixel_counter_x <= 0;
        pixel_counter_y <= 0;
        x <= 0;
        y <= 0;
    end
    // end of line
    else if (pixel_counter_x == H_total - 1) begin
        pixel_counter_x <= 0;
        if (pixel_counter_y == V_total - 1) pixel_counter_y <= 0;
        else pixel_counter_y <= pixel_counter_y + 1;
    end    
    else begin
        pixel_counter_x <= pixel_counter_x + 1;
    end
    if (pixel_counter_x < H_active) x <= pixel_counter_x;
    else x <= 0;
    if (pixel_counter_y < V_active) y <= pixel_counter_y;
    else y <= 0; 
end

assign de = (pixel_counter_x < H_active && pixel_counter_y < V_active);
assign hsync = ~(pixel_counter_x >= H_active + Front_Porch_H && pixel_counter_x < H_active + Front_Porch_H + Hsync);
assign vsync = ~(pixel_counter_y >= V_active + Front_Porch_V && pixel_counter_y < V_active + Front_Porch_V + Vsync);


endmodule