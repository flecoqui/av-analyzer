const path = require('path');
const CopyWebpackPlugin = require('copy-webpack-plugin');

module.exports = {
  mode: "development",
  entry:{ main: [ './src/common.ts',
     './src/globalconfig.ts',
     './src/globalclient.ts',
     './src/globalvars.ts',
     './src/navmanager.ts',
     './src/notificationclient.ts',
     './src/idialog.ts',
     './src/ipage.ts',
     './src/storage.ts',
     './src/dialog.ts',
     './src/page.ts',
    './src/main.ts',
    ],
    result: './src/result.ts',
    live: './src/live.ts',
    record: './src/record.ts',
    settings: './src/settings.ts',
    stringsenUS: './src/strings-en-US.ts',
    stringsfrFR: './src/strings-fr-FR.ts',
    stringsitIT: './src/strings-it-IT.ts',
    stringsptPT: './src/strings-pt-PT.ts',
    stringsdeDE: './src/strings-de-DE.ts',
    stringsesSP: './src/strings-es-SP.ts',
  },
  devtool: 'inline-source-map',
  module: {
    rules: [
      {
        test: /\.ts(x?)$/,
        exclude: ['/node_modules/'],
        use: [
          {
            loader: 'ts-loader',
            options: {
              compilerOptions: {
                noEmit: false,
              },
            },
          },
        ]
      },
    ],
  },
  resolve: {
    extensions: ['.ts', '.js'],
  },
  output: {
    //filename: 'main-bundle.js',
    filename:'[name]-bundle.js',
    path: path.resolve(__dirname, 'build'),
  },
  plugins: [
    new CopyWebpackPlugin(
      {
      patterns: [
        {from: "./html/index.html", to: "./"},
        {from: "./html/result.html", to: "./"},
        {from: "./html/live.html", to: "./"},
        {from: "./html/record.html", to: "./"},
        {from: "./html/settings.html", to: "./"},
        {from: "./html/navmanager.css", to: "./"},
        {from: "./html/index.css", to: "./"},
        {from: "./html/favicon.svg", to: "./"},
        {from: "./src/config.json", to: "./"},
        {from: "./html/dist/img/home_1.png", to: "./dist/img/home_1.png"},
        {from: "./html/dist/img/home_2.png", to: "./dist/img/home_2.png"},
        {from: "./html/dist/img/home_3.png", to: "./dist/img/home_3.png"},
        {from: "./html/dist/css/font-awesme.css", to: "./dist/css/font-awesme.css"},
        {from: "./html/dist/css/font-awesome.min.css", to: "./dist/css/font-awesome.min.css"},
        {from: "./html/dist/fonts/fontawesome-webfont.eot", to: "./dist/fonts/fontawesome-webfont.eot"},
        {from: "./html/dist/fonts/fontawesome-webfont.svg", to: "./dist/fonts/fontawesome-webfont.svg"},
        {from: "./html/dist/fonts/fontawesome-webfont.ttf", to: "./dist/fonts/fontawesome-webfont.ttf"},
        {from: "./html/dist/fonts/fontawesome-webfont.woff", to: "./dist/fonts/fontawesome-webfont.woff"},
        {from: "./html/dist/fonts/fontawesome-webfont.woff2", to: "./dist/fonts/fontawesome-webfont.woff2"},
        {from: "./html/dist/js/bootstrap-table-en-US.min.js", to: "./dist/js/bootstrap-table-en-US.min.js"},
        {from: "./html/dist/js/bootstrap-table-it-IT.min.js", to: "./dist/js/bootstrap-table-it-IT.min.js"},
        {from: "./html/dist/js/bootstrap-table-fr-FR.min.js", to: "./dist/js/bootstrap-table-fr-FR.min.js"},
        {from: "./html/dist/js/bootstrap-table-de-DE.min.js", to: "./dist/js/bootstrap-table-de-DE.min.js"},
        {from: "./html/dist/js/bootstrap-table-pt-PT.min.js", to: "./dist/js/bootstrap-table-pt-PT.min.js"},
        {from: "./html/dist/js/bootstrap-table-es-SP.min.js", to: "./dist/js/bootstrap-table-es-SP.min.js"}
       ],
      }
    ),     
  ],
};
