#!/usr/bin/env node

/**
 * Opens the input in the default browser if it is an URL.
 * Resolves the page title, or warns if no DNS domain can be resolved
 *
 * Requires request and html-entities, install in the script directory using
 *  `npm i request html-entities`
 *
 * Config usage:
 * => exec=node
 * => params=path/to/web.js
 * => name="Web"
 */

'use strict';

const readline = require('readline');
const request = require('request');

const Entities = require('html-entities').AllHtmlEntities;
const entities = new Entities();

const TITLE_REGEX = /<title>(.*?)<\/title>/m;

const debounce = function debounce(func, wait, immediate) {
  let timeout;
  return function() {
    const context = this;
    const args = arguments;
    const later = function() {
      timeout = null;
      if (!immediate) func.apply(context, args);
    };
    const callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
    if (callNow) func.apply(context, args);
  };
};

const getTitleAtUrl = debounce(function getTitleAtUrl(url, resolve, reject) {
  request(url, (error, response, body) => {
    if (!error && response.statusCode === 200) {
      const md = TITLE_REGEX.exec(body);
      if (md) {
        resolve(entities.decode(md[1]));
      }
      resolve();
    } else {
      reject(error);
    }
  });
}, 500);

const WebBackend = {
  rl: null,
  promises: [],

  run: function() {
    this.rl = readline.createInterface({
      input: process.stdin,
      output: process.stderr,
    });
    this.getInput();
  },

  getInput: function() {
    this.rl.question('> ', input => {
      let output;
      if (this.isUri(input)) {
        output = this.makeOutput(input);
      } else {
        output = this.makeOutput();
      }
      process.stdout.write(`${output}\n`);
      this.getInput();
    });
  },

  makeOutput: function(uri) {
    if (!uri) {
      return this.returnJSON(null, null, false);
    }
    if (!/^(?:https?|ftp):\/\/[^\s]+$/.test(uri)) {
      uri = `http://${uri}`;
    }

    const promise = this.getPageName(uri);
    this.promises.push(promise);
    promise
      .then(name => {
        if (promise === this.promises[this.promises.length - 1]) {
          const updatedOutput = this.returnJSON(uri, name, false);
          process.stderr.write('\n');
          process.stdout.write(`${updatedOutput}\n`);
          process.stderr.write('> ');
        }
        this.promises = this.promises.filter(p => p !== promise);
      })
      .catch(err => {
        const updatedOutput = this.returnJSON(
          uri,
          'website (Domain not found)',
          false
        );
        console.error(err);
        process.stderr.write('\n');
        process.stdout.write(`${updatedOutput}\n`);
        process.stderr.write('> ');
        this.promises = this.promises.filter(p => p !== promise);
      });

    return this.returnJSON(uri, null, true);
  },

  returnJSON: function(uri, pageName, loading = false) {
    return JSON.stringify({
      backend: 'Web',
      version: '1.0.0',
      priority: 9,
      loading: loading,
      results: uri ? this.serializeUri(uri, pageName) : [],
    });
  },

  serializeUri: function(uri, pageName) {
    let title = pageName || 'website';
    return [
      {
        name: `Go to ${title}`,
        description: uri,
        icon: 'browser',
        exec: `xdg-open ${uri}`,
      },
    ];
  },

  getPageName: function(uri) {
    return new Promise((resolve, reject) => {
      getTitleAtUrl(uri, resolve, reject);
    });
  },

  isUri: function(uri) {
    return /^(?:(?:https?|ftp):\/\/)?(?:www\.)?[^\s]+\.[^\s]+$/.test(uri);
  },
};

WebBackend.run();
