module top (input       clk,
            output wire hsync,
            output wire vsync,
            output wire video,
            output wire led,
            input       ps2_data,
            input       ps2_clk,
            inout       pin_usb_p,
            inout       pin_usb_n,
            output wire pin_pu
            );
   localparam ROW_BITS = 5;
   localparam COL_BITS = 7;
   localparam ADDR_BITS = 11;

   // pll outputs
   wire locked;
   wire fast_clk;
   // video generator
   wire vblank, hblank;
   // char buffer write char
   wire [7:0] new_char;
   wire [ADDR_BITS-1:0] new_char_address;
   wire new_char_wen;
   // scroll
   wire [ADDR_BITS-1:0] new_first_char;
   wire new_first_char_wen;
   wire [ADDR_BITS-1:0] first_char;
   // cursor
   wire [ROW_BITS-1:0]  new_cursor_y;
   wire [COL_BITS-1:0]  new_cursor_x;
   wire new_cursor_wen;
   wire cursor_blink_on;
   wire [ROW_BITS-1:0] cursor_y;
   wire [COL_BITS-1:0] cursor_x;

   // USB
   // Generate reset signal
   reg [5:0] reset_cnt = 0;
   wire reset = ~reset_cnt[5];
   always @(posedge fast_clk)
     if ( locked )
       reset_cnt <= reset_cnt + reset;

   // uart pipeline in
   wire [7:0] uart_out_data;
   wire uart_out_valid;
   wire uart_out_ready;

   wire [7:0] uart_in_data;
   wire uart_in_valid;
   wire uart_in_ready;

   // TODO rewrite these instantiations to use the param names
   pll mypll(clk, fast_clk, locked);
   keyboard mykeyboard(fast_clk, reset, ps2_data, ps2_clk,
                       uart_in_data, uart_in_valid, uart_in_ready
                       );
   cursor mycursor(fast_clk, reset, vblank, cursor_x, cursor_y, cursor_blink_on,
                   new_cursor_x, new_cursor_y, new_cursor_wen
                   );
   simple_register #(.SIZE(ADDR_BITS)) myscroll_register(fast_clk, reset, new_first_char, new_first_char_wen, first_char);
   // TODO pass COLUMNS & ROWS PARAMS
   video_generator myvideo_generator(fast_clk, reset,
                                     hsync, vsync, video, hblank, vblank,
                                     cursor_x, cursor_y, cursor_blink_on,
                                     first_char,
                                     new_char_address, new_char, new_char_wen,
                                     );
   // usb uart - this instantiates the entire USB device.
   usb_uart uart (.clk_48mhz  (fast_clk),
                  .reset      (reset),
                  // pins
                  .pin_usb_p( pin_usb_p ),
                  .pin_usb_n( pin_usb_n ),
                  // uart pipeline in (keyboard->process)
                  .uart_in_data( uart_in_data ),
                  .uart_in_valid( uart_in_valid ),
                  .uart_in_ready( uart_in_ready ),
                  // uart pipeline out (process->screen)
                  .uart_out_data( uart_out_data ),
                  .uart_out_valid( uart_out_valid ),
                  .uart_out_ready( uart_out_ready  )
                  );

   command_handler mycommand_handler (fast_clk, reset,
                                      uart_out_data, uart_out_valid, uart_out_ready,
                                      new_first_char, new_first_char_wen,
                                      new_char, new_char_address, new_char_wen,
                                      new_cursor_x, new_cursor_y, new_cursor_wen);

   // USB host detect
   assign pin_pu = 1'b1;
   // led follows the cursor blink
   assign led = cursor_blink_on;
 endmodule