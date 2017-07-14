// Copyright (c) 2017, teja. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart' as http;

class ClientCookie {
  final String domain;

  final DateTime expires;

  final bool httpOnly;

  final int maxAge;

  final String name;

  final String path;

  final bool secure;

  final String value;

  final DateTime createdAt;

  ClientCookie(this.name, this.value,
      {this.domain,
        this.expires,
        this.httpOnly: false,
        this.maxAge,
        this.secure: false,
        this.path}): createdAt = new DateTime.now();

  factory ClientCookie.fromMap(String name, String value, Map map) {
    return new ClientCookie(
        name,
        value,
        domain: map['Domain'],
        expires: map['Expires'],
        httpOnly: map['HttpOnly']??false,
        maxAge: map['Max-Age'],
        secure: map['Secure']??false,
        path: map['Path'],
    );
  }

  String _formatDate(DateTime datetime) {
    /* To Dart team: why i have to do this?! this is so awkward (need native JS Date()!!§) */
    final day = ['Mon', 'Tue', 'Wed', 'Thi', 'Fri', 'Sat', 'Sun'];
    final mon = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    var _intToString = (int i, int pad) {
      var str = i.toString();
      var pads = pad - str.length;
      return (pads > 0) ? '${new List.filled(pads, '0').join('')}$i' : str;
    };

    var utc = datetime.toUtc();
    var hour = _intToString(utc.hour, 2);
    var minute = _intToString(utc.minute, 2);
    var second = _intToString(utc.second, 2);

    return '${day[utc.weekday-1]}, ${utc.day} ${mon[utc.month-1]} ${utc.year} ' +
        '${hour}:${minute}:${second} ${utc.timeZoneName}';
  }

  String get header {
    final sb = new StringBuffer();

    //TODO encode all

    sb.write(name);
    sb.write('=');
    if(value is String) sb.write(value);

    return sb.toString();
  }

  String toString() {
    final sb = new StringBuffer();

    //TODO encode all

    sb.write(name);
    sb.write('=');
    if(value is String) sb.write(value);

    if(httpOnly) sb.write('; HttpOnly');
    if(secure) sb.write('; Secure');
    if(path is String) sb.write('; Path=$path');
    if(domain is String) sb.write('; Domain=$domain');
    if(maxAge is int) sb.write('; Max-Age=$maxAge');
    if(expires is DateTime) sb.write('; Max-Age=${_formatDate(expires)}');

    return sb.toString();
  }

  bool get hasExpired {
    if(expires is DateTime) {
      //TODO
      return false;
    }

    if(maxAge is int) {
      //TODO
      return false;
    }

    return false;
  }
}

class CookieJar {
  Map<String, ClientCookie> _cookies = {};

  ClientCookie get(String name) {
    if(!_cookies.containsKey(name)) return null;

    final ret = _cookies[name];

    if(ret.hasExpired) {
      _cookies.remove(name);
      return null;
    }

    return ret;
  }

  String get header {
    final removes = <String>[];
    final rets = <String>[];

    for(ClientCookie cookie in _cookies.values) {
      if(cookie.hasExpired) {
        removes.add(cookie.name);
        continue;
      }
      rets.add(cookie.header);
    }

    for(String rem in removes) _cookies.remove(rem);

    return rets.join('; ');
  }

  void addResponse(http.Response resp) {
    final String setCookieLine = resp.headers['set-cookie'];
    if (setCookieLine is! String || setCookieLine.isEmpty) return;

    final List<String> setCookieItems = setCookieLine.split(',');
    try {
      List<ClientCookie> cookies = setCookieItems.map(addOneCookie).toList();
      for(ClientCookie cookie in cookies) {
        if(cookie.value == null || cookie.value.isEmpty) {
          _cookies.remove(cookie.name);
          continue;
        }
        _cookies[cookie.name] = cookie;
      }
    } catch(e) {
    }
  }

  static final Map<String, dynamic> _v = <String, dynamic>{
    'Expires': (String val) {
      //TODO
    },
    'Max-Age': (String val) {
      if(val is! String) throw new Exception('Invalid Max-Age directive!');
      return int.parse(val);
    },
    'Domain': (String val) {
      if(val is! String) throw new Exception('Invalid Domain directive!');
      return val;
    },
    'Path': (String val) {
      if(val is! String) throw new Exception('Invalid Path directive!');
      return val;
    },
    'Secure': (String val) {
      if(val != null) throw new Exception('Invalid Secure directive!');
      return true;
    },
    'HttpOnly': (String val) {
      if(val != null) throw new Exception('Invalid HttpOnly directive!');
      return true;
    },
    'SameSite': (String val) {
      if(val is! String) throw new Exception('Invalid SameSite directive!');
      return val;
    },
  };

  ClientCookie addOneCookie(String cookieItem) {
    final List<String> parts =
    cookieItem.split(';').reversed.map((String str) => str.trim()).toList();

    if (parts.length == 0) {
      throw new Exception('Invalid cookie set!');
    }

    String name;
    String value;
    final map = {};

    {
      final String first = parts.removeLast();
      final int idx = first.indexOf('=');
      if(idx == -1) throw new Exception('Invalid Name=Value pair!');
      name = first.substring(0, idx).trim();
      value = first.substring(idx+1).trim();
      if (name.isEmpty) throw new Exception('Cookie must have a name!');
    }

    for (String directive in parts) {
      final List<String> points =
      directive.split('=').map((String str) => str.trim()).toList();
      if (points.length == 0 || points.length > 2)
        throw new Exception('Invalid directive!');
      final String key = points.first;
      final String val = points.length == 2 ? points.last : null;
      if (!_v.containsKey(key)) {
        throw new Exception('Invalid directives found!!');
      }
      map[key] = _v[key](val);
    }

    return new ClientCookie.fromMap(name, value, map);
  }

  String toString() {
    return 'CookieJar($_cookies)';
  }
}
