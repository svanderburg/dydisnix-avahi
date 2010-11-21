#include <avahi-client/client.h>
#include <avahi-client/lookup.h>
#include <avahi-common/simple-watch.h>
#include <avahi-common/error.h>
#include <avahi-common/strlst.h>
#include <avahi-common/address.h>
#include <avahi-common/malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static AvahiSimplePoll *simple_poll = NULL;

/* Called whenever a service has been resolved successfully or timed out */

static void resolve_callback(
  AvahiServiceResolver *r,
  AvahiIfIndex interface,
  AvahiProtocol protocol,
  AvahiResolverEvent event,
  const char *name,
  const char *type,
  const char *domain,
  const char *host_name,
  const AvahiAddress *address,
  uint16_t port,
  AvahiStringList *txt,
  AvahiLookupResultFlags flags,
  void *userdata)
{
    switch(event)
    {
	case AVAHI_RESOLVER_FAILURE:
	    fprintf(stderr, "(Resolver) Failed to resolve service '%s' of type '%s' in domain '%s': %s\n", name, type, domain, avahi_strerror(avahi_client_errno(avahi_service_resolver_get_client(r))));
	    break;
				
	case AVAHI_RESOLVER_FOUND: 
	{
	    char a[AVAHI_ADDRESS_STR_MAX], *text, *hostname_keypair, *hostname;
	    AvahiStringList *list_hostname;
		    
	    fprintf(stderr, "Service '%s' of type '%s' in domain '%s':\n", name, type, domain);
				
	    avahi_address_snprint(a, sizeof(a), address);
	    text = avahi_string_list_to_string(txt);
	    
	    fprintf(stderr,
		    "\t%s:%u (%s)\n"
		    "\tTXT=%s\n"
		    "\tcookie is %u\n"
		    "\tis_local: %i\n"
		    "\tour_own: %i\n"
		    "\twide_area: %i\n"
		    "\tmulticast: %i\n"
		    "\tcached: %i\n",
		    host_name, port, a,
		    text,
		    avahi_string_list_get_service_cookie(txt),
		    !!(flags & AVAHI_LOOKUP_RESULT_LOCAL),
	            !!(flags & AVAHI_LOOKUP_RESULT_OUR_OWN),
		    !!(flags & AVAHI_LOOKUP_RESULT_WIDE_AREA),
		    !!(flags & AVAHI_LOOKUP_RESULT_MULTICAST),
		    !!(flags & AVAHI_LOOKUP_RESULT_CACHED));
	    
	    list_hostname = avahi_string_list_find(txt, "hostname");
	    hostname_keypair = avahi_string_list_get_text(list_hostname);
	    hostname = strndup(hostname_keypair + 10, strlen(hostname_keypair) - 10 - 1); /* Get the value after the key= minus the surrounding " */
	    
	    printf("  %s = {\n", hostname);
	    
	    while(txt != NULL)
	    {
		printf("    %s;\n", avahi_string_list_get_text(txt));
		txt = txt->next;
	    }
	    
	    printf("  };\n");
	    
	    free(hostname);
	    avahi_free(text);
	    break;
	}
    }
    
    avahi_service_resolver_free(r);
}						    

/* Called whenever a new services becomes available on the LAN or is removed from the LAN */

static void browse_callback(
  AvahiServiceBrowser *b,
  AvahiIfIndex interface,
  AvahiProtocol protocol,
  AvahiBrowserEvent event,
  const char *name,
  const char *type,
  const char *domain,
  AvahiLookupResultFlags flags,
  void *userdata)
{
    AvahiClient *client = (AvahiClient*)userdata;
    
    switch(event)
    {
	case AVAHI_BROWSER_FAILURE:
	    fprintf(stderr, "(Browser) %s\n", avahi_strerror(avahi_client_errno(avahi_service_browser_get_client(b))));
	    avahi_simple_poll_quit(simple_poll);	    
	    return;
	
	case AVAHI_BROWSER_NEW:
	    fprintf(stderr, "(Browser) NEW: service '%s' of type '%s' in domain '%s'\n", name, type, domain);
	    
	     /* We ignore the returned resolver object. In the callback
	      * function we free it. If the server is terminated before
	      * the callback function is called the server will free
	      * the resolver for us.
	      */
	
	    if((avahi_service_resolver_new(client, interface, protocol, name, type, domain, AVAHI_PROTO_UNSPEC, 0, resolve_callback, client)) == 0)
		fprintf(stderr, "Failed to resolve service '%s': %s\n", name, avahi_strerror(avahi_client_errno(client)));
	
	    break;
	
	case AVAHI_BROWSER_REMOVE:
	    fprintf(stderr, "(Browser) REMOVE: service '%s' of type '%s' in domain '%s'\n", name, type, domain);
	    break;
	
	case AVAHI_BROWSER_ALL_FOR_NOW:
	    fprintf(stderr, "(Browser) ALL_FOR_NOW\n");
	    avahi_simple_poll_quit(simple_poll);
	    break;
	
	case AVAHI_BROWSER_CACHE_EXHAUSTED:
	    fprintf(stderr, "(Browser) CACHE_EXHAUSTED\n");
	    break;
    }
}

/* Called whenever the client or server state changes */

static void client_callback(AvahiClient *c, AvahiClientState state, void *userdata)
{
    if(state == AVAHI_CLIENT_FAILURE)
    {
        fprintf(stderr, "Server connection failure: %s\n", avahi_strerror(avahi_client_errno(c)));
        avahi_simple_poll_quit(simple_poll);
    }
}

int main(int argc, char *argv[])
{
    AvahiClient *client;
    AvahiServiceBrowser *browser;    
    int error;
    
    if((simple_poll = avahi_simple_poll_new()) == NULL)
    {
	fprintf(stderr, "Cannot create simple poll object\n");
	return 1;
    }
    
    if((client = avahi_client_new(avahi_simple_poll_get(simple_poll), 0, client_callback, NULL, &error)) == NULL)
    {
	fprintf(stderr, "Failed to create client: %s\n", avahi_strerror(error));
	avahi_simple_poll_free(simple_poll);
	return 1;
    }
    
    if((browser = avahi_service_browser_new(client, AVAHI_IF_UNSPEC, AVAHI_PROTO_UNSPEC, "_disnix._tcp", NULL, 0, browse_callback, client)) == NULL)
    {
	fprintf(stderr, "Failed to create service browser: %s\n", avahi_strerror(avahi_client_errno(client)));
	avahi_client_free(client);
	avahi_simple_poll_free(simple_poll);
	return 1;
    }
    
    printf("{\n");
    
    /* Run the main loop */
    avahi_simple_poll_loop(simple_poll);
    
    printf("}\n");
    
    avahi_service_browser_free(browser);    
    avahi_client_free(client);
    avahi_simple_poll_free(simple_poll);

    return 0;
}
