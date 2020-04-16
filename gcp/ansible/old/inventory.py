#!/usr/bin/env python
# -*- coding: utf-8 -*-

from collections import defaultdict
import os.path
import configparser
import argparse
import json
import sys
from googleapiclient import discovery



def list_instances(project='silken-period-262510', zone='europe-west1-b', use_gcloud_config=True, use_cache=False,
                   cache_source='dynamic_inventory.cache', update_cache=False,
                   cache_destination='dynamic_inventory.cache'):
    # Retrieving mycfg configuration from gcloud SDK
    gcloud_default_config = os.path.expanduser('~') + '/.config/gcloud/configurations/config_mycfg'
    if use_gcloud_config and os.path.isfile(gcloud_default_config):
        config = configparser.ConfigParser()
        config.read(gcloud_default_config)
        project = config['core'].get('project', project)
        zone = config['compute'].get('zone', zone)
    if use_cache:
        with open(cache_source, 'r', encoding='utf-8') as f:
            try:
                result = json.load(f)
                return result
            except json.decoder.JSONDecodeError as err:
                raise Exception(f'{cache_source} is corrupted')
    else:
        compute = discovery.build('compute', 'v1')
        instances = compute.instances().list(project=project, zone=zone).execute()
        result = instances['items'] if 'items' in instances else None
        if update_cache:
            with open(cache_destination, 'w', encoding='utf-8') as f:
                json.dump(instances, f, indent=2)
        return result


def host_vars(args_host=None):
    return {}


def prepare_ansible_config(instances, dynamic_mode=True):
    ansible_default_group = 'ungrouped'
    ansible_group_label = 'ansible_group'
    tree = lambda: defaultdict(tree)
    ansible_data = tree()
    if not instances:
        instances = []
    for instance in instances:
        name = instance['name']
        private_ip = instance['networkInterfaces'][0]['networkIP']
        if 'accessConfigs' in instance['networkInterfaces'][0] and 'natIP' in \
                instance['networkInterfaces'][0]['accessConfigs'][0]:
            public_ip = instance['networkInterfaces'][0]['accessConfigs'][0]['natIP']
        else:
            public_ip = None
        ip = public_ip if public_ip else private_ip
        if 'labels' in instance and ansible_group_label in instance['labels']:
            ansible_group = instance['labels'][ansible_group_label]
        else:
            ansible_group = ansible_default_group
        if dynamic_mode:
            ansible_data[ansible_group].setdefault('hosts', [])
            ansible_data[ansible_group]['hosts'].append(ip)
            ansible_data[ansible_group].setdefault('vars', {})
        else:
            ansible_data[ansible_group]['hosts'][name]['ansible_host'] = ip
            ansible_data['vars'] = {}
    if dynamic_mode:
        ansible_data['_meta']['hostvars'] = {}
    return json.dumps(ansible_data, sort_keys=True, indent=2)


def main():
    parser = argparse.ArgumentParser(description='Dynamic inventory for Ansible')
    parser.add_argument('--list', action='store_true', dest='list', default=argparse.SUPPRESS,
                        help='Returns configuration for Ansible in JSON format')
    parser.add_argument('--host', action='store', dest='host', default=argparse.SUPPRESS,
                        help='Returns hostvars for a host')
    parser.add_argument('--use-cache', action='store', nargs='?', dest='cache_source', const='dynamic_inventory.cache',
                        default=argparse.SUPPRESS,
                        help=('Instructs the script to load inventory from a file with GCP'
                              'cache (default: dynamic_inventory.cache)'))
    parser.add_argument('--update-cache', action='store', nargs='?', dest='cache_destination',
                        const='dynamic_inventory.cache', default=argparse.SUPPRESS,
                        help=('Saves the newly retrieved data to a cache file (default: dynamic_inventory.cache). '
                              'Ignored if --use-cache is specified.'))
    parser.add_argument('--static-mode', action='store_true', dest='static_mode', default=argparse.SUPPRESS,
                        help="Enforces static json format")
    args = parser.parse_args()

    kwargs = {}
    if 'cache_source' in args:
        kwargs['use_cache'] = True
        kwargs['cache_source'] = args.cache_source
    if 'cache_destination' in args:
        kwargs['update_cache'] = True
        kwargs['cache_destination'] = args.cache_destination
    if 'list' not in args and 'host' not in args:
        parser.print_help(sys.stderr)
        return
    if 'list' in args:
        instances = list_instances(**kwargs)
        if 'static_mode' in args and args.static_mode:
            print(prepare_ansible_config(instances, dynamic_mode=False))
        else:
            print(prepare_ansible_config(instances))
    elif 'host' in args:
        print(host_vars(args.host))


if __name__ == '__main__':
    main()
