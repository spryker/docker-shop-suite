<?php
use Spryker\Shared\Application\ApplicationConstants;
use Spryker\Shared\Collector\CollectorConstants;
use Spryker\Shared\Customer\CustomerConstants;
use Spryker\Shared\GlueApplication\GlueApplicationConstants;
use Spryker\Shared\Newsletter\NewsletterConstants;
use Spryker\Shared\ProductManagement\ProductManagementConstants;
use Spryker\Shared\PropelQueryBuilder\PropelQueryBuilderConstants;
use Spryker\Shared\Propel\PropelConstants;
use Spryker\Shared\RabbitMq\RabbitMqEnv;
use Spryker\Shared\Search\SearchConstants;
use Spryker\Shared\Session\SessionConstants;
use Spryker\Shared\Setup\SetupConstants;
use Spryker\Shared\Storage\StorageConstants;
use Spryker\Shared\ZedRequest\ZedRequestConstants;


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


/** Database credentials **/
$config[PropelConstants::ZED_DB_USERNAME] = getenv('POSTGRES_USER');
$config[PropelConstants::ZED_DB_PASSWORD] = getenv('POSTGRES_PASSWORD');
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
unset($config[SearchConstants::ELASTICA_PARAMETER__AUTH_HEADER]);
$ELASTICA_PARAMETER__EXTRA = [
    // TODO: add here aws region and other extra config you need, for example
    'aws_region' => 'eu-central-1',
    'transport' => 'AwsAuthV4'
];
$config[ApplicationConstants::ELASTICA_PARAMETER__EXTRA] = $ELASTICA_PARAMETER__EXTRA;
$config[SearchConstants::ELASTICA_PARAMETER__EXTRA] = $ELASTICA_PARAMETER__EXTRA;



/** RabbitMQ **/
$config[RabbitMqEnv::RABBITMQ_API_HOST] = getenv('RABBITMQ_HOST');
$config[RabbitMqEnv::RABBITMQ_API_PORT] = getenv('RABBITMQ_API_PORT');
$config[RabbitMqEnv::RABBITMQ_API_USERNAME] = getenv('RABBITMQ_USER');
$config[RabbitMqEnv::RABBITMQ_API_PASSWORD] = getenv('RABBITMQ_PASSWORD');
$config[RabbitMqEnv::RABBITMQ_CONNECTIONS] = [
    'DE' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'DE-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME => getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => '/DE_' . getenv('APPLICATION_ENV') . '_zed',
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['DE'],
        RabbitMqEnv::RABBITMQ_DEFAULT_CONNECTION => true,
    ],
    'AT' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'AT-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME =>  getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => '/AT_' . getenv('APPLICATION_ENV') . '_zed',
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['AT'],
    ],
    'US' => [
        RabbitMqEnv::RABBITMQ_CONNECTION_NAME => 'US-connection',
        RabbitMqEnv::RABBITMQ_HOST => getenv('RABBITMQ_HOST'),
        RabbitMqEnv::RABBITMQ_PORT => getenv('RABBITMQ_PORT'),
        RabbitMqEnv::RABBITMQ_PASSWORD => getenv('RABBITMQ_PASSWORD'),
        RabbitMqEnv::RABBITMQ_USERNAME => getenv('RABBITMQ_USER'),
        RabbitMqEnv::RABBITMQ_VIRTUAL_HOST => '/US_' . getenv('APPLICATION_ENV') . '_zed',
        RabbitMqEnv::RABBITMQ_STORE_NAMES => ['US'],
    ],
];

/**  Queue **/
//$config[QueueConstants::QUEUE_WORKER_INTERVAL_MILLISECONDS] = 1000;
//$config[QueueConstants::QUEUE_WORKER_LOG_ACTIVE] = false;
//$config[QueueConstants::QUEUE_WORKER_OUTPUT_FILE_NAME] = 'data/DE/logs/ZED/queue.out';

/** Jenkins **/
$config[SetupConstants::JENKINS_BASE_URL] = 'http://' . getenv('JENKINS_HOST') . ':' . getenv('JENKINS_PORT') . '/';
$config[SetupConstants::JENKINS_DIRECTORY] = '/var/jenkins_home';
