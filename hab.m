function [] = hab ()
    %% LOAD CONFIGURATION %%
    
    % get experiment directory
    base_dir = [ uigetdir([], 'Select experiment directory') '/' ];
    
    % load the tab-delimited configuration file
    config = ReadStructsFromText([base_dir 'config.txt']);
    
    disp(sprintf('You are running %s\n\n',get_config('StudyName')));

    %% SETUP EXPERIMENT AND SET SESSION VARIABLES %%
    
    % tell matlab to shut up, and seed it's random numbers
    warning('off','all');
    random_seed = sum(clock);
    rand('twister',random_seed);

    [ year, month, day, hour, minute, sec ] = datevec(now);
    start_time = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
    
    % create results struct
    results = struct('key',{},'value',{});
    
    results(length(results) + 1).key = 'Start Time';
    results(length(results)).value = start_time;
    
    % get subject code
    experimenter = input('Enter your (experimenter) name: ','s');
    subject_code = input('Enter subject code: ', 's');
    subject_sex = input('Enter subject sex (M/F):  ', 's');
    subject_age = input('Enter subject age (in months; e.g., X.XX): ', 's');
    
    % begin logging now, because we have the subject_code
    create_log_file();
    log_msg(sprintf('Set base dir: %s',base_dir));
    log_msg('Loaded config file');
    log_msg(sprintf('Study name: %s',get_config('StudyName')));
    log_msg(sprintf('Random seed set as %s via "twister"',num2str(random_seed)));
    log_msg(sprintf('Start time: %s',start_time));
    log_msg(sprintf('Experimenter: %s',experimenter));
    log_msg(sprintf('Subject Code: %s',subject_code));
    log_msg(sprintf('Subject Sex: %s',subject_sex));
    log_msg(sprintf('Subject Age: %s',subject_age));

    results(length(results) + 1).key = 'Experimenter';
    results(length(results)).value = experimenter;
    results(length(results) + 1).key = 'Subject Code';
    results(length(results)).value = subject_code;
    results(length(results) + 1).key = 'Subject Sex';
    results(length(results)).value = subject_sex;
    results(length(results) + 1).key = 'Subject Age';
    results(length(results)).value = subject_age;
    
    %% RANDOMLY SHUFFLE PHASES %%
    
    total_phases = get_config('Phases');
    phase_order = randperm(total_phases);
    
    log_msg(sprintf('Phase Order: %d',[phase_order]));

    disp(sprintf('\n\nPhase Order: %d', [phase_order]));
    
    results(length(results) + 1).key = 'Phase Order';
    results(length(results)).value = phase_order;

    % wait for experimenter to press Enter to begin
    disp(upper(sprintf('\n\nPress any key to launch the experiment window\n\n')));
    KbWait([], 2);
    
    log_msg('Experimenter has launched the experiment window');

    %% SETUP SCREEN %%

    if (get_config('DebugMode') == 1)
        % skip sync tests for faster load
        Screen('Preference','SkipSyncTests', 1);
        log_msg('Running in DebugMode');
    else
        % shut up
        Screen('Preference', 'SuppressAllWarnings', 1);
        log_msg('Not running in DebugMode');
    end

    % disable the keyboard
    ListenChar(2);

    % create window
    screen = max(Screen('Screens'));
    
    wind = Screen('OpenWindow',screen);
    
    log_msg(sprintf('Using screen #',num2str(screen)));
    
    % initialize sound driver
    log_msg('Initializing sound driver...');
    InitializePsychSound;
    log_msg('Sound driver initialized.');
    
    % we may want PNG images
    Screen('BlendFunction', wind, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);

    % grab height and width of screen
    res = Screen('Resolution',screen);
    sheight = res.height;
    swidth = res.width;
    winRect = Screen('Rect', wind);
    
    log_msg(sprintf('Screen resolution is %s by %s',num2str(swidth),num2str(sheight)));

    % wait to begin experiment
    Screen('TextFont', wind, 'Helvetica');
    Screen('TextSize', wind, 25);
    DrawFormattedText(wind, 'Press any key to begin!', 'center', 'center');
    Screen('Flip', wind);

    KbWait([], 2);
    
    log_msg('Experimenter has begun experiment.');

    %% RUN EXPERIMENT PHASES %%

    % attract initial attention
    play_movie(get_config('AttentionGetter'));

    phase_counter = 0;
    for phase = phase_order
        phase_counter = phase_counter + 1;
        
        %% HABITUATION (NON-ALTERNATING) %%
        
        results(length(results) + 1).key = 'Phase';
        results(length(results)).value = phase;
        
        % show checkerboard
        show_image(get_config(['Phase' num2str(phase) 'Image']));
        
        % loop until the baby habituates, max = 10 blocks
        habituated = 0;
        for count = 1:10
            looking_time = play_sound(get_config(['Phase' num2str(phase) 'HabSound']), 12);
            
            log_msg(sprintf('Looking time during block %s: %s',num2str(count),num2str(looking_time)));
            
            if (count == 1) 
                % set habituation criterion
                hab_criterion = looking_time * get_config('HabCriterion');
                
                log_msg(sprintf('Habituation criterion: %s',num2str(hab_criterion)));
                
                results(length(results) + 1).key = 'Hab Criterion';
                results(length(results)).value = hab_criterion;
            else
                % check for habituation
                if looking_time <= hab_criterion
                    % habituated
                    habituated = 1;
                    
                    results(length(results) + 1).key = 'Habituation Block';
                    results(length(results)).value = count;
                    
                    results(length(results) + 1).key = 'Habituated Block LT';
                    results(length(results)).value = looking_time;
                    
                    log_msg('Habituated');
                    break;
                end
            end
        end
        
        % did they habituate?
        if (habituated == 0)
            results(length(results) + 1).key = 'Habituation Block';
            results(length(results)).value = 'NA';

            results(length(results) + 1).key = 'Habituated Block LT';
            results(length(results)).value = 'NA';

            log_msg('Did not habituate!');
        end
        
        %% TEST (ALTERNATING) %%
        
        looking_time = play_sound(get_config(['Phase' num2str(phase) 'TestSound']), 6);
            
        log_msg(sprintf('Looking time during test: %s',num2str(looking_time)));

        results(length(results) + 1).key = 'Test Block LT';
        results(length(results)).value = looking_time;
        
        if (phase_counter < get_config('Phases'))
            %% ATTENTION GETTERS!! %%
            play_movie(get_config('AttentionGetter'));
            play_movie(get_config('AttentionGetterLong'));
            play_movie(get_config('AttentionGetterLong'));
            play_movie(get_config('AttentionGetterLong'));
            play_movie(get_config('AttentionGetter'));
        end
    end

    %% POST-EXPERIMENT CLEANUP %%

    post_experiment(false);

    %% HELPER FUNCTIONS %%
    
    function [value] = get_config (name)
        matching_param = find(cellfun(@(x) strcmpi(x, name), {config.Parameter}));
        value = [config(matching_param).Setting];
    end

    function [key_pressed] = key_pressed ()
        [~,~,keyCode] = KbCheck;
        
        if sum(keyCode) > 0
            key_pressed = true;
        else
            key_pressed = false;
        end
        
        % should we abort
        if strcmpi(KbName(keyCode),'ESCAPE')
            log_msg('Aborting experiment due to ESCAPE key press.');
            post_experiment(true);
        end
    end
    
    function post_experiment (aborted)
        log_msg('Experiment ended');
        
        if (aborted == false)
            % get experimenter comments
            %comments = input('Enter your final comments and press ENTER to save: ','s');

            [ year, month, day, hour, minute, sec ] = datevec(now);
            end_time = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];

            
            results(length(results) + 1).key = 'End Time';
            results(length(results)).value = end_time;
            results(length(results) + 1).key = 'Status';

            if (aborted == true)
                results(length(results)).value = 'ABORTED!';
            else
                results(length(results)).value = 'Completed';
            end
            
            % save session file
            filename = [base_dir 'sessions/' subject_code '.txt'];
            log_msg(sprintf('Saving results file to %s',filename));
            WriteStructsToText(filename,results)
        else
            disp('Experiment aborted - results file not saved, but there is a log.');
        end
        
        ListenChar(0);
        Screen('CloseAll');
        Screen('Preference', 'SuppressAllWarnings', 0);
    end

    function show_image (image_name)
        filename = [base_dir 'stimuli/' image_name];
        
        log_msg(sprintf('Showing image: %s',filename));
        
        % show the image
        [image map alpha] = imread(filename);
        % PNG support
        if ~isempty(regexp(image_name, '.*\.png'))
            log_msg('It is a PNG file');
            image(:,:,4) = alpha(:,:);
        end
        
        imtext = Screen('MakeTexture', wind, image);
        
        % position image in center
        texRect = Screen('Rect', imtext);
        
        l = (swidth / 2) - (texRect(3)/2);
        t = (sheight / 2) - (texRect(4)/2);
        r = (swidth / 2) + (texRect(3)/2);
        b = (sheight / 2) + (texRect(4)/2);
        
        Screen('DrawTexture', wind, imtext, [0 0 texRect(3) texRect(4)], [l t r b]);
        
        Screen('Flip', wind);
    end

    function [time_accumulated] = play_sound (file, count)
        if nargin < 2
            count = 1;
        end
        
        sound_file = [base_dir get_config('StimuliFolder') '/' file];
        log_msg(sprintf('Playing sound: %s',sound_file));
        
        if (sound_file ~= false)
            [wav, freq] = wavread(sound_file);
            wav_data = wav';
            num_channels = size(wav_data,1);
            
            try
                % Try with the 'freq'uency we wanted:
                pahandle = PsychPortAudio('Open', [], [], 0, freq, num_channels);
            catch
                % Failed. Retry with default frequency as suggested by device:
                psychlasterror('reset');
                pahandle = PsychPortAudio('Open', [], [], 0, [], num_channels);
            end
            
            % Fill the audio playback buffer with the audio data 'wavedata':
            PsychPortAudio('FillBuffer', pahandle, wav_data);

            % Start audio playback for 'repetitions' repetitions of the sound data,
            % start it immediately (0) and wait for the playback to start, return onset
            % timestamp.
            PsychPortAudio('Start', pahandle, count, 0, 1);
        end
        
        time_accumulated = 0;
        keypress_start = 0;
        % loop indefinitely
        while (1 ~= 2)
            % track looking time
            if key_pressed()
                if (keypress_start == 0)
                    % start a keypress
                    keypress_start = GetSecs();
                end
            else
                if (keypress_start > 0)
                    % add to accumulated time
                    time_accumulated = time_accumulated + (GetSecs - keypress_start);
                end
                
                % reset keypress
                keypress_start = 0;
            end
            
            % end logic
            status = PsychPortAudio('GetStatus', pahandle);
            if (status.Active == 0)
                if (key_pressed())
                    time_accumulated = time_accumulated + (GetSecs - keypress_start);
                end
                
                PsychPortAudio('Stop', pahandle);
                PsychPortAudio('Close', pahandle);
                
                break;
            end
        end
    end
    
    function play_movie (name)
        filename = [base_dir get_config('StimuliFolder') '/' name];
        log_msg(sprintf('Playing movie: %s',filename));
        
        movie = Screen('OpenMovie', wind, filename);
        
        % Start playback engine:
        Screen('PlayMovie', movie, 1);
        
        % set these parameters so we can resize the video
        texRect = 0;
        
        % loop indefinitely
        while (1 ~= 2)
            tex = Screen('GetMovieImage', wind, movie);
            
            % restart movie?
            if tex < 0
                Screen('PlayMovie', movie, 0);
                Screen('CloseMovie', movie);
                Screen('Flip', wind);
                
                break
            else
                % Draw the new texture immediately to screen:
                if (texRect == 0)
                    texRect = Screen('Rect', tex);
                    
                    % calculate scale factors
                    scale_w = winRect(3) / texRect(3);
                    scale_h = winRect(4) / texRect(4);
                    
                    dstRect = CenterRect(ScaleRect(texRect, scale_w, scale_h), Screen('Rect', wind));
                end
                
                Screen('DrawTexture', wind, tex, [], dstRect);

                % Update display:
                Screen('Flip', wind);
                
                % Release texture:
                Screen('Close', tex);
            end
        end
        
        log_msg('Movie ended');
    end

    function create_log_file ()
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'w');
        fclose(fileID);
    end

    function log_msg (msg)
        fileID = fopen([base_dir 'logs/' subject_code '-' start_time '.txt'],'a');
        
        [ year, month, day, hour, minute, sec ] = datevec(now);
        timestamp = [num2str(year) '-' num2str(month) '-' num2str(day) ' ' num2str(hour) ':' num2str(minute) ':' num2str(sec) ];
        
        fprintf(fileID,'%s - %s\n',timestamp,msg);
        fclose(fileID);
    end
end