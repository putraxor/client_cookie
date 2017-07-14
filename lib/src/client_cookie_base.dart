// Copyright (c) 2017, teja. All rights reserved. Use of this source code
// is governed by a BSD-style license that can be found in the LICENSE file.

import 'package:http/http.dart' as http;

/// Client cookie
class ClientCookie {
  /// Cookie domain
  final String domain;

  /// Cookie expiry date
  final DateTime expires;

  /// Is cookie HTTP only?
  final bool httpOnly;

  /// Max age of cookie
  final int maxAge;

  /// Cookie name
  final String name;

  /// Cookie path
  final String path;

  /// Should the cookie be only sent on secure requests?
  final bool secure;

  /// Value of cookie
  final String value;

  /// TIme at which cookie was created
  final DateTime createdAt;

  ClientCookie(this.name, this.value, this.createdAt,
      {this.domain,
      this.expires,
      this.httpOnly: false,
      this.maxAge,
      this.secure: false,
      this.path});

  /// Receives directives as [Map]
  factory ClientCookie.fromMap(
      String name, String value, DateTime createdAt, Map map) {
    return new ClientCookie(
      name,
      value,
      createdAt,
      domain: map['Domain'],
      expires: map['Expires'],
      httpOnly: map['HttpOnly'] ?? false,
      maxAge: map['Max-Age'],
      secure: map['Secure'] ?? false,
      path: map['Path'],
    );
  }

  /// Formats Date
  String _formatDate(DateTime datetime) {
    /* To Dart team: why i have to do this?! this is so awkward (need native JS Date()!!§) */
    final day = ['Mon', 'Tue', 'Wed', 'Thi', 'Fri', 'Sat', 'Sun'];
    final mon = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

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

  /// Returns a [String] representation that can be written directly to [http.Request]
  /// 'cookie' header
  String get header {
    final sb = new StringBuffer();

    //TODO encode all

    sb.write(name);
    sb.write('=');
    if (value is String) sb.write(value);

    return sb.toString();
  }

  /// Returns a [String] representation that can be directly written to 'set-cookie'
  /// header of server response
  String get setCookie => toString();

  /// String representation that is useful for debug printing
  String toString() {
    final sb = new StringBuffer();

    //TODO encode all

    sb.write(name);
    sb.write('=');
    if (value is String) sb.write(value);

    if (httpOnly) sb.write('; HttpOnly');
    if (secure) sb.write('; Secure');
    if (path is String) sb.write('; Path=$path');
    if (domain is String) sb.write('; Domain=$domain');
    if (maxAge is int) sb.write('; Max-Age=$maxAge');
    if (expires is DateTime) sb.write('; Max-Age=${_formatDate(expires)}');

    return sb.toString();
  }

  /// Returns [true] if the cookie has expired
  bool get hasExpired {
    if (expires is DateTime) {
      //TODO
      return false;
    }

    if (maxAge is int) {
      //TODO
      return false;
    }

    return false;
  }
}

/// A store for Cookies
class CookieStore {
  /// The actual storeage
  Map<String, ClientCookie> _cookies = {};

  /// Returns a cookie by [name]
  ///
  /// Returns [null] if cookie with name is not present
  ClientCookie get(String name) {
    if (!_cookies.containsKey(name)) return null;

    final ret = _cookies[name];

    // Remove expired cookie
    if (ret.hasExpired) {
      _cookies.remove(name);
      return null;
    }

    return ret;
  }

  /// Returns a [String] representation that can be directly written [http.Request]
  /// header
  String get header {
    final removes = <String>[];
    final rets = <String>[];

    for (ClientCookie cookie in _cookies.values) {
      if (cookie.hasExpired) {
        removes.add(cookie.name);
        continue;
      }
      rets.add(cookie.header);
    }

    for (String rem in removes) _cookies.remove(rem);

    return rets.join('; ');
  }

  /// Parses and adds all 'set-cookies' from [http.Response] to the Cookie store
  void addResponse(http.Response resp) {
    final String setCookieLine = resp.headers['set-cookie'];
    if (setCookieLine is! String || setCookieLine.isEmpty) return;

    final List<String> setCookieItems = setCookieLine.split(',');
    try {
      List<ClientCookie> cookies = setCookieItems.map(addOneCookie).toList();
      for (ClientCookie cookie in cookies) {
        if (cookie.value == null || cookie.value.isEmpty) {
          _cookies.remove(cookie.name);
          continue;
        }
        _cookies[cookie.name] = cookie;
      }
    } catch (e) {}
  }

  /// Parses and adds one 'set-cookie' item
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
      if (idx == -1) throw new Exception('Invalid Name=Value pair!');
      name = first.substring(0, idx).trim();
      value = first.substring(idx + 1).trim();
      if (name.isEmpty) throw new Exception('Cookie must have a name!');
    }

    for (String directive in parts) {
      final List<String> points =
          directive.split('=').map((String str) => str.trim()).toList();
      if (points.length == 0 || points.length > 2)
        throw new Exception('Invalid directive!');
      final String key = points.first;
      final String val = points.length == 2 ? points.last : null;
      if (!_parsers.containsKey(key)) {
        throw new Exception('Invalid directives found!!');
      }
      map[key] = _parsers[key](val);
    }

    return new ClientCookie.fromMap(name, value, new DateTime.now(), map);
  }

  /// String representation that is useful for debug printing
  String toString() {
    return 'CookieJar($_cookies)';
  }

  /// A map of field to parser function
  static final Map<String, dynamic> _parsers = <String, dynamic>{
    'Expires': (String val) {
      //TODO
    },
    'Max-Age': (String val) {
      if (val is! String) throw new Exception('Invalid Max-Age directive!');
      return int.parse(val);
    },
    'Domain': (String val) {
      if (val is! String) throw new Exception('Invalid Domain directive!');
      return val;
    },
    'Path': (String val) {
      if (val is! String) throw new Exception('Invalid Path directive!');
      return val;
    },
    'Secure': (String val) {
      if (val != null) throw new Exception('Invalid Secure directive!');
      return true;
    },
    'HttpOnly': (String val) {
      if (val != null) throw new Exception('Invalid HttpOnly directive!');
      return true;
    },
    'SameSite': (String val) {
      if (val is! String) throw new Exception('Invalid SameSite directive!');
      return val;
    },
  };
}
