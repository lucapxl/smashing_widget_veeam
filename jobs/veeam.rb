SCHEDULER.every '60', :first_in => 0 do
    
    require 'rest-client'
    require 'base64'
    require 'nokogiri'

    # make sure you edit these variables to fit your environment
    veeamAPIUrl = 'http://VEEAMSERVERHOST:9399/api/'
    username = 'username'
    password = 'password'

    #######################################################################
    sessionMngrURL = veeamAPIUrl + 'sessionMngr/?v=latest'
    logoffURL = veeamAPIUrl + '/logonSessions/'
    queryURL = veeamAPIUrl + 'query' 

    token= ''
    sessionID = '' 
    veeam_message = ''
    veeam_status = 0
    veeam_count = [0,0,0,0]
    checked_jobs = []

    #UTC time minus 1h
    timespan1day = Time.now.utc - (60 * 60 * 24 * 3) 
    timespan1day = timespan1day.strftime('%Y-%m-%dT%H:%M:%SZ')

    #UTC time minus 1week
    timespan1week = Time.now.utc - (60 * 60 * 24 * 7) 
    timespan1week = timespan1week.strftime('%Y-%m-%dT%H:%M:%SZ')

    # Veeam create a new api session
    response = RestClient::Request.new({
        method: :post,
        url: sessionMngrURL,
        user: username,
        password: password
    }).execute do |response, request, result|
        case response.code
        when 201
            token = response.headers[:x_restsvcsessionid]
            xmlStr = response.to_str
            xmlRes = Nokogiri::XML(xmlStr)
            sessionID = xmlRes.at('SessionId').text
        else
            fail "error: #{response.to_str}"
        end
    end

    #if the token exists, let's query the veeam backup jobs 
    if token.length > 0

        #JobType: Backup, BackupCopy ()
        #Retrieve all backup jobs
        jobs1d = RestClient.get queryURL, {
            :x_restsvcsessionid => token, 
            :params => {
                :type => 'BackupJobSession', 
                :sortDesc => 'CreationTime', 
                :format => 'Entities',
                :filter => 'CreationTime>'+timespan1day
            }
        }
        jobs1dXML = Nokogiri::XML(jobs1d)
        #Filter last session backups
        
        jobs1dXML.css('BackupJobSession').each do |child|
            if child.at('JobType').text == "Backup"
                if !checked_jobs.include? child.at('JobUid').text 
                    checked_jobs.push(child.at('JobUid').text)
                    if child.at('Result').text == "Failed"
                        veeam_message += "<p class='single-message-header'><i class='fa fa-exclamation-circle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Backup " + child.at('Result').text  + "</span></p>"
                        veeam_status = 3
                        veeam_count[3] += 1
                    end
                    if child.at('Result').text == "Warning"
                        veeam_message += "<p class='single-message-header'><i class='fa fa-exclamation-triangle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Backup " + child.at('Result').text  + "</span></p>"
                        if veeam_status < 2
                            veeam_status = 2
                        end
                        veeam_count[2] += 1
                    end 
                    if child.at('Result').text == "None"
                        veeam_message += "<p class='single-message-header'><i class='fa fa-info-circle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Backup " + child.at('State').text + " - " + child.at('Progress').text + "%</span></p>"
                        if veeam_status < 1
                            veeam_status = 1
                        end
                        veeam_count[1] += 1
                    end 
                    if child.at('Result').text == "Success"
                        veeam_count[0] += 1
                    end 
                end
            end
        end


        #Retrieve all replica jobs
        replica1d = RestClient.get queryURL, {
            :x_restsvcsessionid => token, 
            :params => {
                :type => 'ReplicaJobSession', 
                :sortDesc => 'CreationTime', 
                :format => 'Entities',
                :filter => 'CreationTime>'+timespan1day
            }
        }
        replica1dXML = Nokogiri::XML(replica1d)
        #Filter last session replica
        replica1dXML.css('ReplicaJobSession').each do |child|
            if !checked_jobs.include? child.at('JobUid').text 
                checked_jobs.push(child.at('JobUid').text)
                if child.at('Result').text == "Failed"
                    veeam_message += "<p class='single-message-header'><i class='fa fa-exclamation-circle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Replication " + child.at('Result').text  + "</span></p>"
                    veeam_status = 3
                    veeam_count[3] += 1
                end
                if child.at('Result').text == "Warning"
                    veeam_message += "<p class='single-message-header'><i class='fa fa-exclamation-triangle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Replication " + child.at('Result').text  + "</span></p>"
                    if veeam_status < 2
                        veeam_status = 2
                    end
                    veeam_count[2] += 1
                end 
                if child.at('Result').text == "None"
                    veeam_message += "<p class='single-message-header'><i class='fa fa-info-circle'></i><span class='servername'>" +  child.at('JobName').text + "</span><span class='detail'>Replication " + child.at('State').text + " - " + child.at('Progress').text + "%</span></p>"
                    if veeam_status < 1
                        veeam_status = 1
                    end
                    veeam_count[1] += 1
                end 
                if child.at('Result').text == "Success"
                    veeam_count[0] += 1
                end 
            end
        end

        veeam_status = veeam_status == 3 ? "red" : (veeam_status == 2 ? "yellow" : (veeam_status > 0 ? "blue" : "green"))
        send_event('veeam', { success: veeam_count[0], info: veeam_count[1], warning: veeam_count[2], failed: veeam_count[3], veeamstatus: veeam_status })
        send_event('messages', { veeam_messages: veeam_message}) 

    else
        veeam_status = "error"
        veeam_message = "<p class='single-message-header'><i class='fa fa-exclamation-circle'></i><span class='servername'>ERROR IN THE VEEAM CHECK</span></p>"
        send_event('veeam', { success: veeam_count[0], info: veeam_count[1], warning: veeam_count[2], failed: veeam_count[3], veeamstatus: veeam_status })
        send_event('messages', { veeam_messages: veeam_message}) 
    end

    #we delete the session for security
    if sessionID.length > 0
        logoffURL = logoffURL + sessionID
        deleteSession = RestClient.delete logoffURL, {:x_restsvcsessionid => token}
        token = ''
        sessionID = ''
    end
end