<?php

use Spryker\Shared\Application\ApplicationConstants;
use Spryker\Shared\Collector\CollectorConstants;
use Spryker\Shared\Customer\CustomerConstants;
use Spryker\Shared\Newsletter\NewsletterConstants;
use Spryker\Shared\ProductManagement\ProductManagementConstants;
use Spryker\Shared\Propel\PropelConstants;
use Spryker\Shared\Search\SearchConstants;
use Spryker\Shared\Session\SessionConstants;
use Spryker\Shared\Setup\SetupConstants;
use Spryker\Shared\Storage\StorageConstants;
use Spryker\Shared\PropelQueryBuilder\PropelQueryBuilderConstants;
use Spryker\Shared\ZedRequest\ZedRequestConstants;
use Spryker\Shared\Log\LogConstants;
use Monolog\Logger;
use Spryker\Shared\RabbitMq\RabbitMqEnv;

// ---------- Yves host
$config[ApplicationConstants::HOST_YVES] = getenv('YVES_HOST');
$config[ApplicationConstants::PORT_YVES] = ':8080';
$config[ApplicationConstants::PORT_SSL_YVES] = '';
$config[ApplicationConstants::BASE_URL_YVES] = sprintf(
    'http://%s%s',
    $config[ApplicationConstants::HOST_YVES],
    $config[ApplicationConstants::PORT_YVES]
);
$config[ApplicationConstants::BASE_URL_SSL_YVES] = sprintf(
    'https://%s%s',
    $config[ApplicationConstants::HOST_YVES],
    $config[ApplicationConstants::PORT_SSL_YVES]
);
$config[ProductManagementConstants::BASE_URL_YVES] = $config[ApplicationConstants::BASE_URL_YVES];
$config[NewsletterConstants::BASE_URL_YVES] = $config[ApplicationConstants::BASE_URL_YVES];
$config[CustomerConstants::BASE_URL_YVES] = $config[ApplicationConstants::BASE_URL_YVES];
$config[ApplicationConstants::YVES_TRUSTED_HOSTS] = [];

// ---------- Zed host
$config[ApplicationConstants::HOST_ZED] = getenv('ZED_HOST');
$config[ApplicationConstants::PORT_ZED] = ':8081';
$config[ApplicationConstants::PORT_SSL_ZED] = '';
$config[ApplicationConstants::BASE_URL_ZED] = sprintf(
    'http://%s%s',
    $config[ApplicationConstants::HOST_ZED],
    $config[ApplicationConstants::PORT_ZED]
);
$config[ApplicationConstants::BASE_URL_SSL_ZED] = sprintf(
    'https://%s%s',
    $config[ApplicationConstants::HOST_ZED],
    $config[ApplicationConstants::PORT_SSL_ZED]
);
$config[ZedRequestConstants::HOST_ZED_API] = $config[ApplicationConstants::HOST_ZED];
$config[ZedRequestConstants::BASE_URL_ZED_API] = $config[ApplicationConstants::BASE_URL_ZED];
$config[ZedRequestConstants::BASE_URL_SSL_ZED_API] = $config[ApplicationConstants::BASE_URL_SSL_ZED];

// ---------- Assets / Media
$config[ApplicationConstants::BASE_URL_STATIC_ASSETS] = $config[ApplicationConstants::BASE_URL_YVES];
$config[ApplicationConstants::BASE_URL_STATIC_MEDIA] = $config[ApplicationConstants::BASE_URL_YVES];
$config[ApplicationConstants::BASE_URL_SSL_STATIC_ASSETS] = $config[ApplicationConstants::BASE_URL_SSL_YVES];
$config[ApplicationConstants::BASE_URL_SSL_STATIC_MEDIA] = $config[ApplicationConstants::BASE_URL_SSL_YVES];

// ---------- Session
$config[SessionConstants::YVES_SESSION_COOKIE_NAME] = $config[ApplicationConstants::HOST_YVES];
$config[SessionConstants::YVES_SESSION_COOKIE_DOMAIN] = $config[ApplicationConstants::HOST_YVES];
$config[SessionConstants::ZED_SESSION_COOKIE_NAME] = $config[ApplicationConstants::HOST_ZED];



/** Database credentials */
$config[PropelConstants::ZED_DB_USERNAME] = getenv('POSTGRES_USER');
$config[PropelConstants::ZED_DB_PASSWORD] = getenv('POSTGRES_PASSWORD');
$config[PropelConstants::ZED_DB_DATABASE] = getenv('POSTGRES_DATABASE');
$config[PropelConstants::ZED_DB_HOST] = getenv('POSTGRES_HOST');
$config[PropelConstants::ZED_DB_PORT] = getenv('POSTGRES_PORT');
$config[PropelConstants::ZED_DB_ENGINE]
    = $config[PropelQueryBuilderConstants::ZED_DB_ENGINE]
    = $config[PropelConstants::ZED_DB_ENGINE_PGSQL];
$config[PropelConstants::USE_SUDO_TO_MANAGE_DATABASE] = false;


/** Elasticsearch  */
$config[ApplicationConstants::ELASTICA_PARAMETER__HOST] = getenv('ELASTICSEARCH_HOST');
$config[ApplicationConstants::ELASTICA_PARAMETER__PORT] = getenv('ELASTICSEARCH_PORT');
$config[ApplicationConstants::ELASTICA_PARAMETER__INDEX_NAME]
    = $config[CollectorConstants::ELASTICA_PARAMETER__INDEX_NAME]
    = $config[SearchConstants::ELASTICA_PARAMETER__INDEX_NAME]
    = 'de_search';
$ELASTICA_PARAMETER__EXTRA = [
    // TODO: add here aws region and other extra config you need, for example
    'aws_region' => 'eu-central-1',
    'transport' => 'AwsAuthV4'
];
$config[ApplicationConstants::ELASTICA_PARAMETER__EXTRA] = $ELASTICA_PARAMETER__EXTRA;
$config[SearchConstants::ELASTICA_PARAMETER__EXTRA] = $ELASTICA_PARAMETER__EXTRA;


/** Session and KV storage */
$config[StorageConstants::STORAGE_REDIS_PROTOCOL] = getenv('REDIS_PROTOCOL');
$config[StorageConstants::STORAGE_REDIS_HOST] = getenv('REDIS_HOST');
$config[StorageConstants::STORAGE_REDIS_PORT] = 6379;
$config[StorageConstants::STORAGE_REDIS_PASSWORD] = getenv('REDIS_PASSWORD');
$config[StorageConstants::STORAGE_REDIS_DATABASE] = 0;

$config[SessionConstants::YVES_SESSION_REDIS_PROTOCOL] = getenv('REDIS_PROTOCOL');
$config[SessionConstants::YVES_SESSION_REDIS_HOST] = getenv('REDIS_HOST');
$config[SessionConstants::YVES_SESSION_REDIS_PORT] = getenv('REDIS_PORT');
$config[SessionConstants::YVES_SESSION_REDIS_PASSWORD] = getenv('REDIS_PASSWORD');
$config[SessionConstants::YVES_SESSION_REDIS_DATABASE] = 1;

$config[SessionConstants::ZED_SESSION_REDIS_PROTOCOL] = getenv('REDIS_PROTOCOL');
$config[SessionConstants::ZED_SESSION_REDIS_HOST] = getenv('REDIS_HOST');
$config[SessionConstants::ZED_SESSION_REDIS_PORT] = getenv('REDIS_PORT');
$config[SessionConstants::ZED_SESSION_REDIS_PASSWORD] = getenv('REDIS_PASSWORD');
$config[SessionConstants::ZED_SESSION_REDIS_DATABASE] = 2;

/** RabbitMQ queue - to be implemented! */
//$config[SystemConfig::ZED_RABBITMQ_HOST] = getenv('RABBITMQ_HOST');
//$config[SystemConfig::ZED_RABBITMQ_PORT] = getenv('RABBITMQ_PORT');
//$config[SystemConfig::ZED_RABBITMQ_USERNAME] = getenv('RABBITMQ_USER');
//$config[SystemConfig::ZED_RABBITMQ_PASSWORD] = getenv('RABBITMQ_PASSWORD');
//$config[SystemConfig::ZED_RABBITMQ_VHOST] = getenv('RABBITMQ_VHOST');

/** RabbitMQ **/
$config[RabbitMqEnv::RABBITMQ_API_HOST] = getenv('RABBITMQ_HOST');
$config[RabbitMqEnv::RABBITMQ_API_PORT] = getenv('RABBITMQ_API_PORT');
$config[RabbitMqEnv::RABBITMQ_API_USERNAME] = getenv('RABBITMQ_USER');
$config[RabbitMqEnv::RABBITMQ_API_PASSWORD] = getenv('RABBITMQ_PASSWORD');
$config[RabbitMqEnv::RABBITMQ_API_VIRTUAL_HOST] = getenv('RABBITMQ_VHOST');
$config[RabbitMqEnv::RABBITMQ_CONNECTIONS] = [
    'DE' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'DE-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME => getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => getenv('RABBITMQ_VHOST'),
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['DE'],
        RabbitMqEnv::RABBITMQ_DEFAULT_CONNECTION => true,
    ],
    'AT' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'AT-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME =>  getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => getenv('RABBITMQ_VHOST'),   #should be another one
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['AT'],
    ],
    'US' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'US-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME => getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => getenv('RABBITMQ_VHOST'),  #should be another one
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['US'],
    ],
];

/** Jenkins **/
$config[SetupConstants::JENKINS_BASE_URL] = 'http://' . getenv('JENKINS_HOST') . ':' . getenv('JENKINS_PORT') . '/';
$config[SetupConstants::JENKINS_DIRECTORY] = '/var/jenkins_home';

$config[LogConstants::LOG_LEVEL] = Logger::ERROR;
