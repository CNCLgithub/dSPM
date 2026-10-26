function results = run_all_tests(options)
% RUN_ALL_TESTS  Execute all validation tests for dspm_reservoir
%
% USAGE:
%   results = run_all_tests()              % Run all tests
%   results = run_all_tests('verbose', true)   % With detailed output
%   results = run_all_tests('folder', 'neural-circuits')  % Specific folder
%
% OUTPUT:
%   results - Structure with test outcomes
%
% EXAMPLE:
%   results = run_all_tests();
%   fprintf('Passed: %d/%d\n', results.passed, results.passed + results.failed);
%
% See also: dspm_reservoir

    arguments
        options.verbose (1,1) logical = true
        options.folder (1,1) string = ""
    end

    % Find the unit-tests directory relative to this file
    thisFile = mfilename('fullpath');
    testDir = fileparts(thisFile);
    
    % Add helpers to path
    helperPath = fullfile(testDir, 'helpers');
    if exist(helperPath, 'dir')
        addpath(helperPath);
        if options.verbose
            fprintf('Added helpers to path: %s\n', helperPath);
        end
    end
    
    fprintf('\n');
    fprintf('╔══════════════════════════════════════════════════════════════════════╗\n');
    fprintf('║                  DSPM RESERVOIR UNIT TEST SUITE                      ║\n');
    fprintf('╠══════════════════════════════════════════════════════════════════════╣\n');
    fprintf('║  Kim & Bassett (2023) - Nature Machine Intelligence                  ║\n');
    fprintf('║  https://doi.org/10.1038/s42256-023-00668-8                          ║\n');
    fprintf('╚══════════════════════════════════════════════════════════════════════╝\n\n');

    % Define test folders and their tests
    allTestFolders = {
        'k-jet-relaxation', {'test_lorenz_scaled'};
        'opcodes-DRAM',     {'test_matrix_opcodes', 'test_dynamical_ram'};
        'neural-circuits',  {'test_logic_gates'};
        'pong',             {'test_collision'};
    };

    results = struct();
    results.passed = 0;
    results.failed = 0;
    results.skipped = 0;
    results.details = {};

    numFolders = size(allTestFolders, 1);
    
    for f = 1:numFolders
        folderName = allTestFolders{f, 1};
        tests = allTestFolders{f, 2};
        
        % Skip if specific folder requested and doesn't match
        if options.folder ~= "" && ~strcmpi(folderName, options.folder)
            continue;
        end
        
        if isempty(tests)
            if options.verbose
                fprintf('📁 %s: (no tests defined)\n', folderName);
            end
            continue;
        end
        
        fprintf('📁 %s\n', folderName);
        fprintf('   %s\n', repmat('-', 1, 60));
        
        numTests = length(tests);
        
        for t = 1:numTests
            testName = tests{t};
            testPath = fullfile(testDir, folderName, [testName '.m']);
            
            if ~exist(testPath, 'file')
                fprintf('   ⚠ %s: FILE NOT FOUND\n', testName);
                results.skipped = results.skipped + 1;
                continue;
            end
            
            if options.verbose
                fprintf('   ▶ Running %s...\n', testName);
            end
            
            % Run test in isolated function
            [success, elapsed, errMsg] = run_single_test(testPath);
            
            if success
                fprintf('   ✓ %s (%.1fs)\n', testName, elapsed);
                results.passed = results.passed + 1;
                results.details{end+1} = struct('name', testName, ...
                    'folder', folderName, 'status', 'PASS', 'time', elapsed);
            else
                fprintf('   ✗ %s: %s\n', testName, errMsg);
                results.failed = results.failed + 1;
                results.details{end+1} = struct('name', testName, ...
                    'folder', folderName, 'status', 'FAIL', 'error', errMsg);
            end
        end
        fprintf('\n');
    end

    % Summary
    fprintf('══════════════════════════════════════════════════════════════════════\n');
    fprintf('  FINAL SUMMARY\n');
    fprintf('══════════════════════════════════════════════════════════════════════\n');
    fprintf('  Passed:  %d\n', results.passed);
    fprintf('  Failed:  %d\n', results.failed);
    fprintf('  Skipped: %d\n', results.skipped);
    fprintf('  Total:   %d\n', results.passed + results.failed + results.skipped);
    fprintf('══════════════════════════════════════════════════════════════════════\n');
    
    if results.failed == 0 && results.passed > 0
        fprintf('  ★ ALL TESTS PASSED ★\n');
    elseif results.failed > 0
        fprintf('  ✗ %d TEST(S) FAILED\n', results.failed);
    else
        fprintf('  ⚠ NO TESTS EXECUTED\n');
    end
    fprintf('══════════════════════════════════════════════════════════════════════\n\n');
end


function [success, elapsed, errMsg] = run_single_test(testPath)
% RUN_SINGLE_TEST  Run a test script in isolation

    success = false;
    elapsed = 0;
    errMsg = '';
    
    % Get the directory containing the test
    [testDir, ~, ~] = fileparts(testPath);
    
    % Save current directory
    origDir = pwd;
    
    try
        % Change to test directory
        cd(testDir);
        
        % Run the test
        tic;
        run_alias(testPath);
        elapsed = toc;
        
        success = true;
        
    catch ME
        elapsed = toc;
        errMsg = ME.message;
    end
    
    % Return to original directory
    cd(origDir);
end

function run_alias(path)

run(path)
end

function run_folder_tests(folderName)
% RUN_FOLDER_TESTS  Run all tests in a specific folder
%
% USAGE:
%   run_folder_tests('neural-circuits')

    run_all_tests('folder', folderName);
end
