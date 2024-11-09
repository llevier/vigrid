--
-- Vigrid authentication on Openresty
--
local ngx = ngx

-- First ensure user is already authenticated basic
if not (ngx.var.http_authorization ~= nil and ngx.var.http_authorization:sub(0, 6) == 'Basic ') then
	-- No ? Authenticate !
	ngx.header["WWW-Authenticate"] = 'Basic realm="Vigrid Access"'
	ngx.status = ngx.HTTP_UNAUTHORIZED
	ngx.say("401 Unauthorized")
	return ngx.exit(ngx.HTTP_UNAUTHORIZED)
else -- Yes, let's check access...
	-- Extract Basic auth
	auth_creds=string.gsub(ngx.var.http_authorization,'^Basic ','',1)
	local vigrid_creds = ngx.decode_base64(auth_creds)

	-- Splitting credentials
	local vigrid_user=string.gsub(vigrid_creds,':.*$','',1)
	local vigrid_pass=string.gsub(vigrid_creds,'^.*:','',1)
	if vigrid_user == '' or vigrid_pass == '' then
		ngx.log(ngx.ERR, 'Unknown Vigrid credentials (', vigrid_creds, ') not granted to pass')
		ngx.exit(401)
		return
	end

	-- Check user is granted to pass
	local grep_str=string.format("egrep '^%s:{PLAIN}%s$' /home/gns3/etc/vigrid-passwd",vigrid_user,vigrid_pass)
	local p = io.popen(grep_str)
	local vigrid_check = p:read('*l')
	p:close()
	
	if vigrid_check == nil then
		ngx.log(ngx.ERR, 'Unknown Vigrid credentials (', vigrid_creds, ') not granted to pass')
		ngx.exit(401)
		return
	end

	-- Yes ? Extract user/pass from gns3_server.conf
	local p = io.popen("egrep '^(user|password)\\s*=' /home/gns3/.config/GNS3/gns3_server.conf")
	local res_user = p:read('*l')
	local res_pass = p:read('*l')
	p:close()
	gns_user=string.gsub(res_user,'^user[ ]+=[ ]+','',1)
	gns_pass=string.gsub(res_pass,'^password[ ]+=[ ]+','',1)

	-- Build base64 header
	local basic = string.format('%s:%s',gns_user,gns_pass)
	local basicb64 = ngx.encode_base64(basic,false)

	-- Replace authorization
	authorization = string.format('Basic %s',basicb64)
	ngx.req.set_header('Authorization', authorization)

	return
end
