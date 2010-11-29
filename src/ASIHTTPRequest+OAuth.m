//
//  ASIHTTPRequest+OAuth.m
//  SimpleGeo
//
//  Created by Seth Fitzsimmons on 11/23/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <CommonCrypto/CommonHMAC.h>
#import "ASIHTTPRequest+OAuth.h"
#import "NSString+URLEncoding.h"
#import "Base64Transcoder.h"


@interface ASIHTTPRequest ()

- (NSString *)generateNonce;
- (NSString *)generateTimestamp;
- (NSString *)normalizeRequestParameters:(NSDictionary*)params;
- (NSString *)signClearText:(NSString *)text
                 withSecret:(NSString *)secret;
- (NSString *)signatureBaseStringWithParameters:(NSDictionary *)params;
@end


@implementation ASIHTTPRequest (OAuth)
+ (id)requestWithURL:(NSURL *)newURL
         consumerKey:(NSString *)consumerKey
      consumerSecret:(NSString *)consumerSecret
{
    return [[[self alloc] initWithURL:newURL
                          consumerKey:consumerKey
                       consumerSecret:consumerSecret] autorelease];
}

- (id)initWithURL:(NSURL *)newURL
      consumerKey:(NSString *)consumerKey
   consumerSecret:(NSString *)consumerSecret
{
    self = [self initWithURL:newURL];

    if (self) {
        // hijack request credentials because this won't be using Basic/Digest
        // Auth or NTLM and these *are* request credentials
        [self setRequestCredentials:[NSDictionary dictionaryWithObjectsAndKeys:
                                     consumerKey, @"consumerKey",
                                     consumerSecret, @"consumerSecret",
                                     nil
                                     ]];
    }

    return self;
}

- (void)applyAuthorizationHeader
{
    if (! [requestCredentials objectForKey:@"consumerKey"] &&
        ! [requestCredentials objectForKey:@"consumerSecret"]) {
        return;
    }

    NSLog(@"Applying OAuth headers...");

    // basic OAuth parameters
    NSMutableDictionary *oauthParams = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                        [requestCredentials objectForKey:@"consumerKey"],
                                        @"oauth_consumer_key",
                                        [self generateTimestamp], @"oauth_timestamp",
                                        [self generateNonce], @"oauth_nonce",
                                        @"HMAC-SHA1", @"oauth_signature_method", 
                                        @"1.0", @"oauth_version",
                                        nil
                                        ];

    NSMutableDictionary *params = [oauthParams mutableCopy];

    // add in params from the query string
    for (NSString *pair in [[url query] componentsSeparatedByString:@"&"]) {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        [params setObject:[kv objectAtIndex:1]
                   forKey:[kv objectAtIndex:0]];
    }

    NSString *sbs = [self signatureBaseStringWithParameters:params];
    NSLog(@"Signature base string: %@", sbs);

    // generate the OAuth signature

    // if this were a 3-legged request, it would be consumerSecret&tokenSecret
    NSString *secret = [NSString stringWithFormat:@"%@&%@",
                        [requestCredentials objectForKey:@"consumerSecret"],
                        @""];
    NSString *signature = [self signClearText:sbs
                                   withSecret:secret];
    [oauthParams setObject:signature
                    forKey:@"oauth_signature"];

    // prepare to assemble an Authorization header
    NSMutableArray *pairs = [NSMutableArray arrayWithCapacity:[oauthParams count]];
    for (NSString *key in oauthParams) {
        [pairs addObject:[NSString stringWithFormat:@"%@=\"%@\"",
                          key, [[oauthParams objectForKey:key] URLEncodedString]]];
    }
    NSString *components = [[NSArray arrayWithArray:pairs] componentsJoinedByString:@", "];

    NSLog(@"Authorization header: %@", [NSString stringWithFormat:@"OAuth realm=\"\", %@", components]);
    [self addRequestHeader:@"Authorization"
                     value:[NSString stringWithFormat:@"OAuth realm=\"\", %@", components]];
}

- (NSString *)generateNonce
{
    CFUUIDRef theUUID = CFUUIDCreate(NULL);
    CFStringRef string = CFUUIDCreateString(NULL, theUUID);
    NSMakeCollectable(theUUID);

    return (NSString *) string;
}

- (NSString *)generateTimestamp
{
    return [NSString stringWithFormat:@"%d", time(NULL)];
}

- (NSString *)normalizeRequestParameters:(NSDictionary*)params
{
    NSMutableArray *parameterPairs = [NSMutableArray arrayWithCapacity:([params count])];

    NSString *value;
    for (NSString *param in params) {
        value = [params objectForKey:param];
        param = [NSString stringWithFormat:@"%@=%@",
                 [param URLEncodedString],
                 [value URLEncodedString]];
        [parameterPairs addObject:param];
    }

    NSArray *sortedPairs = [parameterPairs sortedArrayUsingSelector:@selector(compare:)];
    return [sortedPairs componentsJoinedByString:@"&"];
}

- (NSString *)signatureBaseStringWithParameters:(NSDictionary *)params
{
    return [NSString stringWithFormat:@"%@&%@&%@",
            requestMethod,
            [[[[url absoluteString] componentsSeparatedByString:@"?"] objectAtIndex:0] URLEncodedString],
            [[self normalizeRequestParameters:params] URLEncodedString]];
}

// Adapted from OAuthConsumer/OAHMAC_SHA1SignatureProvider.m
- (NSString *)signClearText:(NSString *)text
                 withSecret:(NSString *)secret
{
    NSData *secretData = [secret dataUsingEncoding:NSUTF8StringEncoding];
    NSData *clearTextData = [text dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char result[20];
	CCHmac(kCCHmacAlgSHA1,
           [secretData bytes],
           [secretData length],
           [clearTextData bytes],
           [clearTextData length],
           result);

    // Base64 Encoding
    char base64Result[32];
    size_t theResultLength = 32;
    Base64EncodeData(result, 20, base64Result, &theResultLength, Base64Flags_Default);
    NSString *base64EncodedResult = [[NSString alloc] initWithFormat:@"%s", base64Result];

    return [base64EncodedResult autorelease];
}

@end
