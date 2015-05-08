# TwitterReporter
Reports twitter accounts.

## Install

```shell
gem install bundler
git clone https://github.com/DinoPew/TwitterReporter.git
cd path/to/TwitterReporter/
bundle install
```

## Usage

#### Basic:

```shell
# By default we get our targets from: https://ghostbin.com/paste/fgrfx/raw
ruby twitter_reporter.rb -u Your_Twitter_Username
```

#### Advanced:

```shell
ruby twitter_reporter.rb -u Your_Twitter_Username -f ~/path/to/targets.txt
```
