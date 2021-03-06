# Veeam Widget for [Smashing](https://smashing.github.io)

[Smashing](https://smashing.github.io) widget that displays the status of **Backup** and **Replication** jobs from a Veeam Server using the REST API provided by the Veeam Enterprise Server.
Unfortunately there is no easy way to get all Veeam Jobs last results using the REST API. The solution I came up with is to collect al the results in a long enough timespan that will include all scheduled jobs. Since there could be more results for the same job, the plugin will only display the last result for each job.
This widget will display the status of the jobs in the following forms:

* Tile background + icon display the highest status in the following order
  * red: one or more jobs failed
  * yellow: one or more jobs ended with a warning
  * blue: one or more jobs are currently running
  * green: all jobs ended successfully
* Number of jobs at the bottom of the tile: OK/RUNNING/WARNING/FAILED

## Example

![veeam ok](https://raw.githubusercontent.com/lucapxl/smashing_widget_veeam/master/images/veeam-ok.png)
![veeam-info](https://raw.githubusercontent.com/lucapxl/smashing_widget_veeam/master/images/veeam-info.png)

## Installation and Configuration

This widget uses `rest-client` `base64` and `nokogiri`. make sure to add them in your dashboard Gemfile
```Gemfile
gem 'rest-client'
gem 'base64'
gem 'nokogiri'
```
and to run the update command to download and install them.

```bash
$ bundle update
```

Create a "veeam" folder in your ```widgets``` directory and clone this repository inside it. 
make a symbolic link of the file ```jobs/veeam.rb``` in the ```/jobs``` directory of your dashboard.
for example, if your smashing installation directory is in ```/opt/dashboard/``` you would run this:
```Shell
$ ln -s /opt/dashboard/widgets/veeam/jobs/veeam.rb /opt/dashboard/jobs/veeam.rb
```

configure `jobs/veeam.rb` job file for your environment:

```ruby
veeamAPIUrl = 'https://yourserver.host.here:9399/api/' # veeam server API url
username = 'username' # veeam user that can access the api
password = 'password' # veeam user password
timespan = (60 * 60 * 24 * 3) # how far back to look for job results
```

add the tile in your dashboard .erb file

```html
    <li data-row="1" data-col="1" data-sizex="1" data-sizey="1">
      <div data-id="veeam" data-view="Veeam" data-title="Veeam"></div>
    </li>
```

## [Messages](https://github.com/lucapxl/smashing_widget_messages) widget integration

Since this widget only displays the status of the Veeam Backup jobs, I had the need to visualize the details in case the status was not OK. The `veeam.rb` job is setup in a way to send detailed information to the widget [Messages](https://github.com/lucapxl/smashing_widget_messages) I developed to organize "messages" of other widgets in a single box.

![messages integration](https://raw.githubusercontent.com/lucapxl/smashing_widget_veeam/master/images/messages-1.png)

## License

Distributed under the MIT license
