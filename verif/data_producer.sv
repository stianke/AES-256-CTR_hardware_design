module data_producer #(
    parameter DATA_WIDTH = 128
)(
    input  logic                  clk,
    input  logic                  rst,
    output logic [DATA_WIDTH-1:0] m_axis_tdata,
    output logic                  m_axis_tvalid,
    output logic                  m_axis_tlast,
    input  logic                  m_axis_tready,
    input  integer                test_number
);

    integer fd_plaintext;
    integer fd_delays;
    integer curr_delay;
    string plaintext_filename;
    string delays_filename;
    integer next_test_number = 0;
    bit file_open = 0;
    logic [DATA_WIDTH-1:0] word;
    
    always_ff @(posedge clk) begin
        m_axis_tvalid <= m_axis_tvalid;
        m_axis_tdata  <= m_axis_tdata;
        m_axis_tlast <= m_axis_tlast;
        
        if (rst) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= '0;
        end else if (curr_delay > 0) begin
            curr_delay = curr_delay - 1;
            if (curr_delay > 0) begin
                m_axis_tvalid <= 0;
                m_axis_tdata  <= '0;
                m_axis_tlast <= 0;
            end else begin
                $fscanf(fd_plaintext, "%h\n", word);
                m_axis_tdata  <= word;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= $feof(fd_plaintext); // last word if file ends
                if ($feof(fd_plaintext)) begin
                    $fclose(fd_plaintext);
                    $fclose(fd_delays);
                    file_open <= 0;
                    $display("Closed plaintext data file %s", plaintext_filename);
                    $display("Closed plaintext delays file %s", delays_filename);
                end
            end
        end else if (m_axis_tvalid) begin
            if (m_axis_tready) begin
                
                $fscanf(fd_delays, "%d\n", curr_delay);
                
                // Set next data point
                if (curr_delay > 0 || file_open == 0) begin
                    m_axis_tvalid <= 0;
                    m_axis_tdata  <= '0;
                    m_axis_tlast <= 0;
                end else begin
                    $fscanf(fd_plaintext, "%h\n", word);
                    m_axis_tdata  <= word;
                    m_axis_tvalid <= 1;
                    m_axis_tlast  <= $feof(fd_plaintext); // last word if file ends
                    if ($feof(fd_plaintext)) begin
                        $fclose(fd_plaintext);
                        $fclose(fd_delays);
                        file_open <= 0;
                        $display("Closed plaintext data file %s", plaintext_filename);
                        $display("Closed plaintext delays file %s", delays_filename);
                    end
                end
            end
        end else if (file_open == 0) begin
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;
            m_axis_tdata  <= '0;
            
            if (test_number == next_test_number) begin // Wait until caller increments to next test
                plaintext_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_plaintext.txt", test_number);
                delays_filename = $sformatf("../../../../../verif/generated_test_data/t_%03d_producer_delay_ticks.txt", test_number);
                
                fd_plaintext = $fopen(plaintext_filename, "r");
                fd_delays = $fopen(delays_filename, "r");
                
                if (fd_plaintext == 0) $fatal(1, "Failed to open plaintext data file: %s", plaintext_filename);
                if (fd_delays == 0) $fatal(1, "Failed to open plaintext delays file: %s", delays_filename);
                
                $display("Opened plaintext data file %s: %0d", plaintext_filename, fd_plaintext);
                $display("Opened plaintext delays file %s: %0d", delays_filename, fd_delays);
                
                $fscanf(fd_plaintext, "%h\n", word);
                curr_delay = 0;
                m_axis_tdata <= word;
                m_axis_tvalid <= 1;
                m_axis_tlast  <= $feof(fd_plaintext);
                
                file_open <= 1;
                next_test_number <= test_number + 1;
            end
        end
    end

endmodule
